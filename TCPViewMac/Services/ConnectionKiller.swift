import Foundation
import Security

/// Handles process termination with optional privilege escalation.
enum ConnectionKiller {

    enum KillError: LocalizedError {
        case authorizationFailed
        case killFailed(Int32)
        case userCancelled

        var errorDescription: String? {
            switch self {
            case .authorizationFailed: "Failed to obtain administrator authorization."
            case .killFailed(let pid): "Failed to terminate process \(pid)."
            case .userCancelled: "Authorization was cancelled."
            }
        }
    }

    /// Kill a process. Tries without elevation first, then escalates if needed.
    static func killProcess(pid: Int32) async throws {
        // Try direct kill first (works for own processes)
        let result = kill(pid, SIGTERM)
        if result == 0 { return }

        // Need elevation
        try await killWithElevation(pid: pid)
    }

    /// Kill using AppleScript elevation (prompts for admin password).
    private static func killWithElevation(pid: Int32) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "do shell script \"kill -TERM \(pid)\" with administrator privileges"
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                appleScript?.executeAndReturnError(&error)

                if let error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                    if code == -128 {
                        continuation.resume(throwing: KillError.userCancelled)
                    } else {
                        continuation.resume(throwing: KillError.killFailed(pid))
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Force kill a process (SIGKILL).
    static func forceKillProcess(pid: Int32) async throws {
        let result = kill(pid, SIGKILL)
        if result == 0 { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "do shell script \"kill -9 \(pid)\" with administrator privileges"
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                appleScript?.executeAndReturnError(&error)

                if let error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                    if code == -128 {
                        continuation.resume(throwing: KillError.userCancelled)
                    } else {
                        continuation.resume(throwing: KillError.killFailed(pid))
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
