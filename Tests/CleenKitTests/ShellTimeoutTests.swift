import Foundation
import Testing
@testable import CleenKit

struct ShellTimeoutTests {
    @Test func collectsOutputAndStatus() async throws {
        let result = try await Shell.run("/bin/echo", ["olá"], timeout: .seconds(5))
        #expect(result.succeeded)
        #expect(result.stdout == "olá\n")
    }

    @Test func stuckProcessIsTerminatedAtTheTimeout() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        await #expect(throws: ShellError.self) {
            _ = try await Shell.run("/bin/sleep", ["30"], timeout: .milliseconds(300))
        }
        #expect(clock.now - start < .seconds(5))
    }

    @Test func timeoutIsReportedAsSuch() async {
        do {
            _ = try await Shell.run("/bin/sleep", ["30"], timeout: .milliseconds(200))
            Issue.record("expected a timeout")
        } catch ShellError.timedOut {
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func fastProcessIsUntouchedByTheTimeout() async throws {
        let result = try await Shell.run("/bin/sleep", ["0.1"], timeout: .seconds(5))
        #expect(result.succeeded)
    }
}
