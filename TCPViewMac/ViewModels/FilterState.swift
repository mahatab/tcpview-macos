import Foundation

@MainActor
@Observable
final class FilterState {
    var searchText: String = ""
    var showListening: Bool = true
    var showIPv6: Bool = true
    var resolveAddresses: Bool = false

    func matches(_ connection: NetworkConnection) -> Bool {
        // Filter listening sockets
        if !showListening && connection.state == .listen {
            return false
        }

        // Filter IPv6
        if !showIPv6 && connection.protocolType.isIPv6 {
            return false
        }

        // Text search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            let searchableFields = [
                connection.processName,
                String(connection.pid),
                connection.protocolType.rawValue,
                connection.localAddress,
                String(connection.localPort),
                connection.remoteAddress,
                String(connection.remotePort),
                connection.state.description
            ]
            return searchableFields.contains { $0.lowercased().contains(query) }
        }

        return true
    }
}
