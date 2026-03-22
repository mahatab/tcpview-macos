import Foundation
import AppKit

enum JSONExporter {

    struct ExportableConnection: Encodable {
        let processName: String
        let pid: Int32
        let `protocol`: String
        let localAddress: String
        let localPort: UInt16
        let remoteAddress: String
        let remotePort: UInt16
        let state: String
        let bytesSent: UInt64
        let bytesReceived: UInt64
    }

    static func export(_ connections: [DisplayConnection]) -> String {
        let exportable = connections.map { dc in
            let c = dc.connection
            return ExportableConnection(
                processName: c.processName,
                pid: c.pid,
                protocol: c.protocolType.rawValue,
                localAddress: c.localAddress,
                localPort: c.localPort,
                remoteAddress: c.remoteAddress,
                remotePort: c.remotePort,
                state: c.state.description,
                bytesSent: c.bytesOut,
                bytesReceived: c.bytesIn
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(exportable),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    @MainActor
    static func saveToFile(_ connections: [DisplayConnection]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "tcpview_export.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let json = export(connections)
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }
}
