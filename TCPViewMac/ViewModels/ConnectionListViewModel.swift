import Foundation
import SwiftUI

@MainActor
@Observable
final class ConnectionListViewModel {
    var monitor = ConnectionMonitor()
    var filterState = FilterState()
    let dnsResolver = DNSResolver()
    let trafficMonitor = TrafficMonitor()

    var resolvedNames: [String: String] = [:]
    var selectedConnectionIDs: Set<String> = []

    var filteredConnections: [DisplayConnection] {
        monitor.displayConnections.filter { filterState.matches($0.connection) }
    }

    func start() {
        monitor.start()
    }

    func stop() {
        monitor.stop()
    }

    func resolvedAddress(for address: String) -> String {
        if !filterState.resolveAddresses { return address }
        return resolvedNames[address] ?? address
    }

    func refreshDNS() async {
        let addresses = Set(monitor.displayConnections.flatMap {
            [$0.connection.localAddress, $0.connection.remoteAddress]
        }.filter { $0 != "*" && !$0.isEmpty })

        let results = await dnsResolver.resolveMany(Array(addresses))
        resolvedNames.merge(results) { _, new in new }
    }

    func killProcess(pid: Int32) async throws {
        try await ConnectionKiller.killProcess(pid: pid)
    }

    func forceKillProcess(pid: Int32) async throws {
        try await ConnectionKiller.forceKillProcess(pid: pid)
    }

    func copyConnectionInfo(_ connection: NetworkConnection) -> String {
        [
            connection.processName,
            String(connection.pid),
            connection.protocolType.rawValue,
            connection.localEndpoint,
            connection.remoteEndpoint,
            connection.state.description
        ].joined(separator: "\t")
    }
}
