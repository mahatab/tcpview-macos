import Foundation

enum RefreshInterval: Double, CaseIterable, Identifiable, Sendable {
    case oneSecond = 1.0
    case twoSeconds = 2.0
    case fiveSeconds = 5.0
    case paused = 0.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .oneSecond: "1 second"
        case .twoSeconds: "2 seconds"
        case .fiveSeconds: "5 seconds"
        case .paused: "Paused"
        }
    }
}

/// Tracks display state for each connection row (color coding).
struct DisplayConnection: Identifiable, Sendable {
    let connection: NetworkConnection
    let displayState: RowDisplayState
    let stateTimestamp: Date

    var id: String { connection.id }
}

/// Monitors network connections with periodic refresh and snapshot diffing.
@MainActor
@Observable
final class ConnectionMonitor {
    var displayConnections: [DisplayConnection] = []
    var refreshInterval: RefreshInterval = .twoSeconds
    var isMonitoring: Bool = true
    var totalCount: Int = 0
    var hasLimitedVisibility: Bool = false

    private var previousSnapshot: ConnectionSnapshot?
    private var closingConnections: [String: (connection: NetworkConnection, timestamp: Date)] = [:]
    private var displayStates: [String: (state: RowDisplayState, timestamp: Date)] = [:]
    private var monitorTask: Task<Void, Never>?

    private let closingRetentionDuration: TimeInterval = 3.0
    private let highlightDuration: TimeInterval = 3.0

    func start() {
        stop()
        isMonitoring = true
        monitorTask = Task { [weak self] in
            // Initial fetch
            await self?.refresh()

            while !Task.isCancelled {
                guard let self else { return }
                let interval = self.refreshInterval
                guard interval != .paused else {
                    try? await Task.sleep(for: .milliseconds(200))
                    continue
                }
                try? await Task.sleep(for: .seconds(interval.rawValue))
                guard !Task.isCancelled else { return }
                await self.refresh()
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }

    func manualRefresh() {
        Task { await refresh() }
    }

    func refresh() async {
        let connections = await Task.detached(priority: .userInitiated) {
            LibProcBridge.enumerateAllSockets()
        }.value

        let newSnapshot = ConnectionSnapshot(connections: connections)
        let now = Date()

        // Diff with previous snapshot
        if let previous = previousSnapshot {
            var newStates = [String: (state: RowDisplayState, timestamp: Date)]()

            // Find new and changed connections
            for (id, conn) in newSnapshot.connections {
                if let oldConn = previous.connections[id] {
                    if oldConn.state != conn.state {
                        newStates[id] = (.changed, now)
                    }
                    // else: keep existing state or normal
                } else {
                    newStates[id] = (.new, now)
                }
            }

            // Find closed connections
            for (id, conn) in previous.connections where newSnapshot.connections[id] == nil {
                if closingConnections[id] == nil {
                    closingConnections[id] = (conn, now)
                }
            }

            // Merge new states with existing (preserve unexpired highlights)
            for (id, existing) in displayStates {
                if newStates[id] == nil && now.timeIntervalSince(existing.timestamp) < highlightDuration {
                    newStates[id] = existing
                }
            }

            displayStates = newStates
        }

        // Prune old closing connections
        closingConnections = closingConnections.filter { (_, value) in
            now.timeIntervalSince(value.timestamp) < closingRetentionDuration
        }

        // Build display list
        var display = connections.map { conn in
            let state = displayStates[conn.id]?.state ?? .normal
            let timestamp = displayStates[conn.id]?.timestamp ?? now
            return DisplayConnection(connection: conn, displayState: state, stateTimestamp: timestamp)
        }

        // Add closing connections (shown in red)
        for (id, entry) in closingConnections {
            if newSnapshot.connections[id] == nil {
                display.append(DisplayConnection(
                    connection: entry.connection,
                    displayState: .closing,
                    stateTimestamp: entry.timestamp
                ))
            }
        }

        previousSnapshot = newSnapshot
        displayConnections = display
        totalCount = connections.count

        // Detect limited visibility (heuristic: if we see very few system processes)
        let uniquePIDs = Set(connections.map(\.pid))
        hasLimitedVisibility = !uniquePIDs.contains(1) // Can't see launchd = likely unprivileged
    }
}
