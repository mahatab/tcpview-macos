import SwiftUI
import AppKit

struct ProcessInfoSheet: View {
    let connection: NetworkConnection
    @State private var processPath: String?
    @State private var bundleID: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Process Info")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Name:").foregroundStyle(.secondary)
                    Text(connection.processName).fontWeight(.medium)
                }
                GridRow {
                    Text("PID:").foregroundStyle(.secondary)
                    Text(String(connection.pid)).monospacedDigit()
                }
                if let path = processPath {
                    GridRow {
                        Text("Path:").foregroundStyle(.secondary)
                        Text(path)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(3)
                    }
                }
                if let bundleID {
                    GridRow {
                        Text("Bundle ID:").foregroundStyle(.secondary)
                        Text(bundleID)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                GridRow {
                    Text("Protocol:").foregroundStyle(.secondary)
                    Text(connection.protocolType.rawValue)
                }
                GridRow {
                    Text("Local:").foregroundStyle(.secondary)
                    Text(connection.localEndpoint)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Remote:").foregroundStyle(.secondary)
                    Text(connection.remoteEndpoint)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("State:").foregroundStyle(.secondary)
                    Text(connection.state.description)
                }
            }

            Divider()

            HStack {
                if let path = processPath {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                }
                Button("Open Activity Monitor") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                }
            }
        }
        .padding()
        .frame(width: 450)
        .task {
            processPath = LibProcBridge.getProcessPath(pid: connection.pid)
            if let path = processPath {
                bundleID = Bundle(url: URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent())?.bundleIdentifier
            }
        }
    }
}
