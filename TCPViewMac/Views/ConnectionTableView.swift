import SwiftUI

struct ConnectionTableView: View {
    @Bindable var viewModel: ConnectionListViewModel
    @State private var sortOrder = [KeyPathComparator(\DisplayConnection.connection.processName)]
    @State private var whoisTarget: String?
    @State private var processInfoTarget: NetworkConnection?
    @State private var errorMessage: String?

    var body: some View {
        Table(sortedConnections, selection: $viewModel.selectedConnectionIDs, sortOrder: $sortOrder) {
            TableColumn("Process", value: \.connection.processName) { item in
                Text(item.connection.processName)
                    .fontWeight(item.connection.state == .listen ? .medium : .regular)
            }
            .width(min: 100, ideal: 150)

            TableColumn("PID", value: \.connection.pid) { item in
                Text(String(item.connection.pid))
                    .monospacedDigit()
            }
            .width(min: 40, ideal: 60)

            TableColumn("Protocol", value: \.connection.protocolType) { item in
                Text(item.connection.protocolType.rawValue)
            }
            .width(min: 50, ideal: 60)

            TableColumn("Local Address") { item in
                Text(viewModel.resolvedAddress(for: item.connection.localAddress))
            }
            .width(min: 100, ideal: 150)

            TableColumn("Local Port", value: \.connection.localPort) { item in
                Text(item.connection.localPort == 0 ? "*" : String(item.connection.localPort))
                    .monospacedDigit()
            }
            .width(min: 50, ideal: 70)

            TableColumn("Remote Address") { item in
                Text(viewModel.resolvedAddress(for: item.connection.remoteAddress))
            }
            .width(min: 100, ideal: 150)

            TableColumn("Remote Port", value: \.connection.remotePort) { item in
                Text(item.connection.remotePort == 0 ? "*" : String(item.connection.remotePort))
                    .monospacedDigit()
            }
            .width(min: 50, ideal: 70)

            TableColumn("State", value: \.connection.state) { item in
                Text(item.connection.protocolType.isUDP ? "" : item.connection.state.description)
                    .foregroundStyle(stateColor(item.connection.state))
            }
            .width(min: 80, ideal: 100)

            TableColumn("Sent", value: \.connection.bytesOut) { item in
                Text(formatBytes(item.connection.bytesOut))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80)

            TableColumn("Received", value: \.connection.bytesIn) { item in
                Text(formatBytes(item.connection.bytesIn))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first, let conn = findConnection(id) {
                Button("Copy Connection Info") {
                    let info = viewModel.copyConnectionInfo(conn)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(info, forType: .string)
                }

                Divider()

                Button("Kill Process (\(conn.processName))") {
                    Task {
                        do {
                            try await viewModel.killProcess(pid: conn.pid)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }

                Button("Force Kill Process") {
                    Task {
                        do {
                            try await viewModel.forceKillProcess(pid: conn.pid)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }

                Divider()

                if conn.remoteAddress != "*" && !conn.remoteAddress.isEmpty {
                    Button("Whois \(conn.remoteAddress)") {
                        whoisTarget = conn.remoteAddress
                    }

                    Button("Whois in Browser") {
                        WhoisService.openInBrowser(conn.remoteAddress)
                    }
                }

                Divider()

                Button("Process Info") {
                    processInfoTarget = conn
                }
            }
        } primaryAction: { ids in
            if let id = ids.first {
                processInfoTarget = findConnection(id)
            }
        }
        .sheet(item: $whoisTarget) { address in
            WhoisSheet(address: address)
        }
        .sheet(item: $processInfoTarget) { conn in
            ProcessInfoSheet(connection: conn)
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var sortedConnections: [DisplayConnection] {
        viewModel.filteredConnections.sorted(using: sortOrder)
    }

    private func findConnection(_ id: String) -> NetworkConnection? {
        viewModel.monitor.displayConnections.first { $0.id == id }?.connection
    }

    private func stateColor(_ state: TCPState) -> Color {
        switch state {
        case .established: .primary
        case .listen: .secondary
        case .closeWait, .finWait1, .finWait2, .closing, .lastAck, .timeWait: .orange
        case .closed: .secondary
        default: .primary
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes == 0 { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
