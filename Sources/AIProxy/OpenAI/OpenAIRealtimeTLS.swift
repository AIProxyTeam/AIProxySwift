import Foundation
import Network

/// Selects the version floor for secure Realtime connections. Network.framework
/// does not apply the URL Loading System's per-domain TLS minimum.
nonisolated enum OpenAIRealtimeTLS {
    static func minimumVersion(
        for host: String,
        exceptionDomains: [String: Any],
        systemMinimum: tls_protocol_version_t
    ) -> tls_protocol_version_t {
        let rule = domainRule(for: host, in: exceptionDomains)
        let requiresTLS13 = rule?["NSExceptionMinimumTLSVersion"] as? String == "TLSv1.3"
        let floor: tls_protocol_version_t = requiresTLS13 ? .TLSv13 : .TLSv12
        return systemMinimum.rawValue > floor.rawValue ? systemMinimum : floor
    }

    private static func domainRule(for host: String, in domains: [String: Any]) -> [String: Any]? {
        guard !domains.isEmpty else { return nil }
        var name = host.lowercased()[...]
        if name.first == "[", name.last == "]" { name = name.dropFirst().dropLast() }
        if let exact = domains[String(name)] as? [String: Any] { return exact }

        if let address = addressBytes(name) {
            // Match IP literals against numeric rules only, using the most specific prefix.
            var longestPrefix = -1
            var match: [String: Any]?
            for (key, value) in domains {
                let parts = key.split(separator: "/", omittingEmptySubsequences: false)
                guard parts.count <= 2, let network = addressBytes(parts[0]),
                      network.count == address.count, let rule = value as? [String: Any] else { continue }
                let bitCount = address.count * 8
                let prefix = parts.count == 2 ? Int(parts[1]) : bitCount
                guard let prefix, (0...bitCount).contains(prefix), prefix > longestPrefix else { continue }
                let bytes = prefix / 8
                guard address.prefix(bytes) == network.prefix(bytes) else { continue }
                let bits = prefix % 8
                if bits > 0, (address[bytes] ^ network[bytes]) >> (8 - bits) != 0 { continue }
                longestPrefix = prefix
                match = rule
            }
            return match
        }

        // A trailing dot is significant to ATS. Walk from the closest parent
        // outward and inherit only a rule that includes its subdomains.
        while let dot = name.firstIndex(of: ".") {
            name = name[name.index(after: dot)...]
            if let parent = domains[String(name)] as? [String: Any],
               parent["NSIncludesSubdomains"] as? Bool == true {
                return parent
            }
        }
        return nil
    }

    private static func addressBytes(_ name: Substring) -> Data? {
        let literal = String(name)
        return IPv4Address(literal)?.rawValue ?? IPv6Address(literal)?.rawValue
    }
}
