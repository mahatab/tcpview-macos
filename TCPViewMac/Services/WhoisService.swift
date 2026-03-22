import Foundation
import AppKit

/// Performs WHOIS lookups for IP addresses.
enum WhoisService {

    struct WhoisResult: Sendable {
        let ipAddress: String
        let rawResponse: String
        let organization: String?
        let country: String?
        let netRange: String?
    }

    static func lookup(_ address: String) async -> WhoisResult? {
        guard !address.isEmpty, address != "*" else { return nil }

        return await Task.detached(priority: .utility) {
            performLookup(address)
        }.value
    }

    /// Opens the WHOIS result in a browser as a fallback.
    @MainActor
    static func openInBrowser(_ address: String) {
        guard let url = URL(string: "https://who.is/whois-ip/ip-address/\(address)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func performLookup(_ address: String) -> WhoisResult? {
        // Connect to whois.iana.org first to find the right server
        guard let response = queryWhoisServer("whois.iana.org", query: address) else {
            return nil
        }

        // Try to find a referral server
        var finalResponse = response
        if let referral = extractReferral(from: response) {
            if let referred = queryWhoisServer(referral, query: address) {
                finalResponse = referred
            }
        }

        return WhoisResult(
            ipAddress: address,
            rawResponse: finalResponse,
            organization: extractField(from: finalResponse, field: "OrgName") ??
                          extractField(from: finalResponse, field: "org-name") ??
                          extractField(from: finalResponse, field: "Organization"),
            country: extractField(from: finalResponse, field: "Country") ??
                     extractField(from: finalResponse, field: "country"),
            netRange: extractField(from: finalResponse, field: "NetRange") ??
                      extractField(from: finalResponse, field: "inetnum")
        )
    }

    private static func queryWhoisServer(_ server: String, query: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/whois")
        process.arguments = ["-h", server, query]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private static func extractReferral(from response: String) -> String? {
        for line in response.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if lower.hasPrefix("refer:") || lower.hasPrefix("referralserver:") {
                let value = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                // Strip whois:// prefix if present
                return value.replacingOccurrences(of: "whois://", with: "")
            }
        }
        return nil
    }

    private static func extractField(from response: String, field: String) -> String? {
        for line in response.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix(field.lowercased() + ":") {
                let value = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}
