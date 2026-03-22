import Foundation

struct ConnectionSnapshot: Sendable {
    let timestamp: Date
    let connections: [String: NetworkConnection]

    init(connections: [NetworkConnection]) {
        self.timestamp = Date()
        var dict = [String: NetworkConnection]()
        dict.reserveCapacity(connections.count)
        for conn in connections {
            dict[conn.id] = conn
        }
        self.connections = dict
    }
}
