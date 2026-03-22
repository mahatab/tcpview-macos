import Foundation
import Darwin

private let kMaxPathSize: Int = 4096 // PROC_PIDPATHINFO_MAXSIZE equivalent

/// Low-level bridge to macOS libproc APIs for enumerating network sockets.
enum LibProcBridge {

    /// Enumerate all TCP and UDP sockets on the system.
    /// Must be called from a background thread — can take 50-200ms on busy systems.
    static func enumerateAllSockets() -> [NetworkConnection] {
        let pids = listAllPIDs()
        var connections = [NetworkConnection]()
        connections.reserveCapacity(pids.count * 4)

        var nameCache = [Int32: String]()

        for pid in pids {
            let fds = listFileDescriptors(for: pid)
            for fd in fds {
                guard fd.proc_fdtype == PROX_FDTYPE_SOCKET else { continue }

                if let conn = socketInfo(pid: pid, fd: fd.proc_fd, nameCache: &nameCache) {
                    connections.append(conn)
                }
            }
        }

        return connections
    }

    // MARK: - Private

    private static func listAllPIDs() -> [Int32] {
        var bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        bufferSize = bufferSize * 2
        var pids = [Int32](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.stride * pids.count))
        guard actualSize > 0 else { return [] }

        return Array(pids.prefix(Int(actualSize)))
    }

    private static func listFileDescriptors(for pid: Int32) -> [proc_fdinfo] {
        let bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        let fdCount = Int(bufferSize) / MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: fdCount + 16)
        let actualSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds,
                                       Int32(MemoryLayout<proc_fdinfo>.stride * fds.count))
        guard actualSize > 0 else { return [] }

        let actualCount = Int(actualSize) / MemoryLayout<proc_fdinfo>.stride
        return Array(fds.prefix(actualCount))
    }

    private static func socketInfo(pid: Int32, fd: Int32, nameCache: inout [Int32: String]) -> NetworkConnection? {
        var fdInfo = socket_fdinfo()
        let size = proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO, &fdInfo,
                                   Int32(MemoryLayout<socket_fdinfo>.size))
        guard size == MemoryLayout<socket_fdinfo>.size else { return nil }

        let si = fdInfo.psi
        let family = si.soi_family
        let sockType = si.soi_type

        guard family == AF_INET || family == AF_INET6 else { return nil }
        guard sockType == SOCK_STREAM || sockType == SOCK_DGRAM else { return nil }

        let isTCP = sockType == SOCK_STREAM
        let kind = si.soi_kind

        var localAddr = ""
        var localPort: UInt16 = 0
        var remoteAddr = ""
        var remotePort: UInt16 = 0
        var tcpState: TCPState = .closed
        var proto: ProtocolType

        if isTCP && kind == SOCKINFO_TCP {
            let tcp = si.soi_proto.pri_tcp
            let ini = tcp.tcpsi_ini
            tcpState = TCPState(rawValue: tcp.tcpsi_state) ?? .closed

            let isV6 = ini.insi_vflag & UInt8(INI_IPV6) != 0
            proto = isV6 ? .tcp6 : .tcp4

            localAddr = formatLocalAddress(ini, isIPv6: isV6)
            localPort = UInt16(bigEndian: UInt16(truncatingIfNeeded: ini.insi_lport))
            remoteAddr = formatForeignAddress(ini, isIPv6: isV6)
            remotePort = UInt16(bigEndian: UInt16(truncatingIfNeeded: ini.insi_fport))
        } else if !isTCP && (kind == SOCKINFO_IN || kind == SOCKINFO_TCP) {
            let ini: in_sockinfo
            if kind == SOCKINFO_TCP {
                ini = si.soi_proto.pri_tcp.tcpsi_ini
            } else {
                ini = si.soi_proto.pri_in
            }

            let isV6 = ini.insi_vflag & UInt8(INI_IPV6) != 0
            proto = isV6 ? .udp6 : .udp4

            localAddr = formatLocalAddress(ini, isIPv6: isV6)
            localPort = UInt16(bigEndian: UInt16(truncatingIfNeeded: ini.insi_lport))
            remoteAddr = formatForeignAddress(ini, isIPv6: isV6)
            remotePort = UInt16(bigEndian: UInt16(truncatingIfNeeded: ini.insi_fport))
            tcpState = .closed
        } else {
            return nil
        }

        if localAddr.isEmpty { localAddr = "*" }
        if remoteAddr.isEmpty || remoteAddr == "0.0.0.0" || remoteAddr == "::" {
            remoteAddr = "*"
        }

        let processName = nameCache[pid] ?? {
            let name = getProcessName(pid: pid)
            nameCache[pid] = name
            return name
        }()

        let connID = NetworkConnection.compositeID(
            pid: pid, proto: proto,
            localAddr: localAddr, localPort: localPort,
            remoteAddr: remoteAddr, remotePort: remotePort
        )

        return NetworkConnection(
            id: connID,
            pid: pid,
            processName: processName,
            processPath: nil,
            protocolType: proto,
            localAddress: localAddr,
            localPort: localPort,
            remoteAddress: remoteAddr,
            remotePort: remotePort,
            state: tcpState,
            bytesIn: 0,
            bytesOut: 0
        )
    }

    // MARK: - Address Formatting

    private static func formatLocalAddress(_ ini: in_sockinfo, isIPv6: Bool) -> String {
        if isIPv6 {
            var addr6 = ini.insi_laddr.ina_6
            var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &addr6, &buf, socklen_t(INET6_ADDRSTRLEN)) != nil else {
                return ""
            }
            return String(cString: buf)
        } else {
            var addr4 = ini.insi_laddr.ina_46.i46a_addr4
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &addr4, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return ""
            }
            return String(cString: buf)
        }
    }

    private static func formatForeignAddress(_ ini: in_sockinfo, isIPv6: Bool) -> String {
        if isIPv6 {
            var addr6 = ini.insi_faddr.ina_6
            var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &addr6, &buf, socklen_t(INET6_ADDRSTRLEN)) != nil else {
                return ""
            }
            return String(cString: buf)
        } else {
            var addr4 = ini.insi_faddr.ina_46.i46a_addr4
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &addr4, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return ""
            }
            return String(cString: buf)
        }
    }

    // MARK: - Process Info

    static func getProcessName(pid: Int32) -> String {
        var name = [CChar](repeating: 0, count: kMaxPathSize)
        let result = proc_name(pid, &name, UInt32(name.count))
        if result > 0 {
            return String(cString: name)
        }
        return "(\(pid))"
    }

    static func getProcessPath(pid: Int32) -> String? {
        var path = [CChar](repeating: 0, count: kMaxPathSize)
        let result = proc_pidpath(pid, &path, UInt32(path.count))
        guard result > 0 else { return nil }
        return String(cString: path)
    }
}
