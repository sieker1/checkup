import Foundation

/// One IP address bound to a network interface.
struct NetworkAddress: Identifiable, Equatable {
    let id: String
    let interface: String
    let family: String
    let address: String
    let isLoopback: Bool
}

enum ConnectivityInfo {
    static func addresses() -> [NetworkAddress] {
        var results: [NetworkAddress] = []
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let entry = current.pointee
            pointer = entry.ifa_next

            let name = String(cString: entry.ifa_name)
            guard let addr = entry.ifa_addr else { continue }
            let family = addr.pointee.sa_family
            let isLoopback = (entry.ifa_flags & UInt32(IFF_LOOPBACK)) != 0

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                              &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(cString: host)
            guard !text.isEmpty else { continue }

            let familyName: String
            switch Int32(family) {
            case AF_INET: familyName = "IPv4"
            case AF_INET6: familyName = "IPv6"
            default: continue
            }

            results.append(NetworkAddress(
                id: "\(name)-\(familyName)-\(text)",
                interface: name,
                family: familyName,
                address: text,
                isLoopback: isLoopback
            ))
        }
        return results.sorted { $0.interface == $1.interface ? $0.family < $1.family : $0.interface < $1.interface }
    }

    /// Convenience: just the routable (non-loopback) addresses, one line each.
    static func summaryLines() -> [String] {
        addresses()
            .filter { !$0.isLoopback }
            .map { "\($0.interface) — \($0.family) \($0.address)" }
    }
}
