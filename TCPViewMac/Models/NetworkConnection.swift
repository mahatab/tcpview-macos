import Foundation

enum ProtocolType: String, CaseIterable, Comparable, Sendable {
    case tcp4 = "TCP"
    case tcp6 = "TCP6"
    case udp4 = "UDP"
    case udp6 = "UDP6"

    var isTCP: Bool { self == .tcp4 || self == .tcp6 }
    var isUDP: Bool { self == .udp4 || self == .udp6 }
    var isIPv6: Bool { self == .tcp6 || self == .udp6 }

    static func < (lhs: ProtocolType, rhs: ProtocolType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum TCPState: Int32, CaseIterable, CustomStringConvertible, Comparable, Sendable {
    case closed = 0
    case listen = 1
    case synSent = 2
    case synReceived = 3
    case established = 4
    case closeWait = 5
    case finWait1 = 6
    case closing = 7
    case lastAck = 8
    case finWait2 = 9
    case timeWait = 10

    var description: String {
        switch self {
        case .closed: "CLOSED"
        case .listen: "LISTEN"
        case .synSent: "SYN_SENT"
        case .synReceived: "SYN_RECV"
        case .established: "ESTABLISHED"
        case .closeWait: "CLOSE_WAIT"
        case .finWait1: "FIN_WAIT_1"
        case .closing: "CLOSING"
        case .lastAck: "LAST_ACK"
        case .finWait2: "FIN_WAIT_2"
        case .timeWait: "TIME_WAIT"
        }
    }

    var isClosing: Bool {
        switch self {
        case .closeWait, .finWait1, .closing, .lastAck, .finWait2, .timeWait, .closed:
            return true
        default:
            return false
        }
    }

    static func < (lhs: TCPState, rhs: TCPState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct NetworkConnection: Identifiable, Hashable, Sendable {
    let id: String
    let pid: Int32
    var processName: String
    var processPath: String?
    let protocolType: ProtocolType
    let localAddress: String
    let localPort: UInt16
    let remoteAddress: String
    let remotePort: UInt16
    var state: TCPState
    var bytesIn: UInt64
    var bytesOut: UInt64

    var localEndpoint: String {
        localPort == 0 ? localAddress : "\(localAddress):\(localPort)"
    }

    var remoteEndpoint: String {
        if remoteAddress == "*" || remoteAddress.isEmpty { return "*" }
        return remotePort == 0 ? remoteAddress : "\(remoteAddress):\(remotePort)"
    }

    static func compositeID(pid: Int32, proto: ProtocolType, localAddr: String, localPort: UInt16, remoteAddr: String, remotePort: UInt16) -> String {
        "\(pid)-\(proto.rawValue)-\(localAddr):\(localPort)-\(remoteAddr):\(remotePort)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NetworkConnection, rhs: NetworkConnection) -> Bool {
        lhs.id == rhs.id
    }
}
