import Foundation
import AppKit

enum CSVExporter {

    static func export(_ connections: [DisplayConnection]) -> String {
        var csv = "Process,PID,Protocol,Local Address,Local Port,Remote Address,Remote Port,State,Sent Bytes,Received Bytes\n"

        for dc in connections {
            let c = dc.connection
            let row = [
                escapeCSV(c.processName),
                String(c.pid),
                c.protocolType.rawValue,
                escapeCSV(c.localAddress),
                String(c.localPort),
                escapeCSV(c.remoteAddress),
                String(c.remotePort),
                c.state.description,
                String(c.bytesOut),
                String(c.bytesIn)
            ].joined(separator: ",")
            csv += row + "\n"
        }

        return csv
    }

    @MainActor
    static func saveToFile(_ connections: [DisplayConnection]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "tcpview_export.csv"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let csv = export(connections)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
