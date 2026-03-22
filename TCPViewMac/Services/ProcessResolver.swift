import Foundation

/// Resolves PID to process name, path, and bundle ID with caching.
actor ProcessResolver {
    private var nameCache: [Int32: String] = [:]
    private var pathCache: [Int32: String] = [:]

    func resolve(pid: Int32) -> (name: String, path: String?) {
        let name: String
        if let cached = nameCache[pid] {
            name = cached
        } else {
            let resolved = LibProcBridge.getProcessName(pid: pid)
            nameCache[pid] = resolved
            name = resolved
        }

        let path: String?
        if let cached = pathCache[pid] {
            path = cached
        } else {
            let resolved = LibProcBridge.getProcessPath(pid: pid)
            if let resolved {
                pathCache[pid] = resolved
            }
            path = resolved
        }

        return (name, path)
    }

    func invalidate(pid: Int32) {
        nameCache.removeValue(forKey: pid)
        pathCache.removeValue(forKey: pid)
    }

    func clearAll() {
        nameCache.removeAll()
        pathCache.removeAll()
    }
}
