import Foundation

/// Async DNS reverse resolver with caching.
actor DNSResolver {
    private var cache: [String: String] = [:]
    private var pending: Set<String> = []
    private let maxConcurrent = 10

    func resolve(_ address: String) async -> String? {
        if address == "*" || address.isEmpty || address == "0.0.0.0" || address == "::" {
            return nil
        }
        if let cached = cache[address] {
            return cached == address ? nil : cached
        }
        guard !pending.contains(address) else { return nil }

        pending.insert(address)
        defer { pending.remove(address) }

        let hostname = await Task.detached(priority: .utility) {
            Self.reverseLookup(address)
        }.value

        if let hostname {
            cache[address] = hostname
        } else {
            cache[address] = address // Negative cache
        }

        return hostname
    }

    func resolveMany(_ addresses: [String]) async -> [String: String] {
        var results = [String: String]()

        // Return cached first
        var uncached = [String]()
        for addr in addresses {
            if addr == "*" || addr.isEmpty { continue }
            if let cached = cache[addr], cached != addr {
                results[addr] = cached
            } else if cache[addr] == nil {
                uncached.append(addr)
            }
        }

        // Resolve uncached in parallel with limited concurrency
        await withTaskGroup(of: (String, String?).self) { group in
            for addr in uncached.prefix(maxConcurrent) {
                group.addTask {
                    let hostname = Self.reverseLookup(addr)
                    return (addr, hostname)
                }
            }
            for await (addr, hostname) in group {
                if let hostname {
                    cache[addr] = hostname
                    results[addr] = hostname
                } else {
                    cache[addr] = addr
                }
            }
        }

        return results
    }

    func clearCache() {
        cache.removeAll()
    }

    private static func reverseLookup(_ address: String) -> String? {
        var hints = addrinfo()
        hints.ai_flags = AI_NUMERICHOST
        hints.ai_family = AF_UNSPEC

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(address, nil, &hints, &result)
        guard status == 0, let addrInfo = result else { return nil }
        defer { freeaddrinfo(addrInfo) }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let niStatus = getnameinfo(
            addrInfo.pointee.ai_addr,
            addrInfo.pointee.ai_addrlen,
            &hostname,
            socklen_t(hostname.count),
            nil, 0,
            NI_NAMEREQD
        )

        guard niStatus == 0 else { return nil }
        let name = String(cString: hostname)
        return name == address ? nil : name
    }
}
