import Foundation

/// Parses nettop output to get per-connection traffic statistics.
actor TrafficMonitor {

    struct TrafficStats: Sendable {
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    /// Key: "proto localAddr:localPort-remoteAddr:remotePort"
    private var stats: [String: TrafficStats] = [:]

    func fetchStats() async -> [String: TrafficStats] {
        let output = await Task.detached(priority: .utility) {
            Self.runNettop()
        }.value

        guard let output else { return stats }

        let parsed = Self.parseNettopOutput(output)
        for (key, value) in parsed {
            stats[key] = value
        }
        return stats
    }

    func statsFor(proto: ProtocolType, localAddr: String, localPort: UInt16,
                  remoteAddr: String, remotePort: UInt16) -> TrafficStats? {
        let protoStr: String
        switch proto {
        case .tcp4: protoStr = "tcp4"
        case .tcp6: protoStr = "tcp6"
        case .udp4: protoStr = "udp4"
        case .udp6: protoStr = "udp6"
        }
        let key = "\(protoStr) \(localAddr):\(localPort)-\(remoteAddr):\(remotePort)"
        return stats[key]
    }

    private static func runNettop() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-n", "-L", "1", "-x", "-k", "bytes_in,bytes_out", "-t", "external"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private static func parseNettopOutput(_ output: String) -> [String: TrafficStats] {
        var results = [String: TrafficStats]()
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Look for lines with connection details like:
            // tcp4 192.168.0.25:56144<->17.57.144.182:5223
            guard let protoRange = trimmed.range(of: #"(tcp[46]|udp[46])\s+"#, options: .regularExpression) else {
                continue
            }

            let proto = String(trimmed[protoRange]).trimmingCharacters(in: .whitespaces)
            let rest = String(trimmed[protoRange.upperBound...])

            // Parse connection identifier
            guard let connMatch = rest.range(of: #"[\d\.\:a-fA-F]+<->[\d\.\:a-fA-F]+"#, options: .regularExpression) else {
                continue
            }

            let connStr = String(rest[connMatch])
            let parts = connStr.components(separatedBy: "<->")
            guard parts.count == 2 else { continue }

            let key = "\(proto) \(parts[0])-\(parts[1])"

            // Parse bytes_in and bytes_out from the CSV fields
            let fields = trimmed.components(separatedBy: ",")
            if fields.count >= 2 {
                let bytesIn = UInt64(fields[fields.count - 2].trimmingCharacters(in: .whitespaces)) ?? 0
                let bytesOut = UInt64(fields[fields.count - 1].trimmingCharacters(in: .whitespaces)) ?? 0
                results[key] = TrafficStats(bytesIn: bytesIn, bytesOut: bytesOut)
            }
        }

        return results
    }
}
