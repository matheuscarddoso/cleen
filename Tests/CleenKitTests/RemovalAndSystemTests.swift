import Foundation
import Testing
@testable import CleenKit

struct RemovalAndSystemTests {
    @Test func deletesWhatItMayAndReportsWhatItMayNot() async throws {
        let sandbox = try Sandbox()
        let cache = try sandbox.folder("Library/Caches/com.example.app")
        try sandbox.file("Library/Caches/com.example.app/blob", bytes: 10_000)
        let remover = FileRemover(safety: SafetyGuard(home: sandbox.root))

        let outcome = await remover.remove([
            RemovalRequest(url: cache, size: 10_000, mode: .delete),
            RemovalRequest(url: sandbox.url("Library/Caches"), size: 1, mode: .delete),
        ])

        #expect(!sandbox.exists("Library/Caches/com.example.app"))
        #expect(sandbox.exists("Library/Caches"))
        #expect(outcome.freed == 10_000)
        #expect(outcome.failures.map(\.url) == [sandbox.url("Library/Caches")])
    }

    @Test func alreadyMissingItemsAreNotCountedAsFreed() async throws {
        let sandbox = try Sandbox()
        let remover = FileRemover(safety: SafetyGuard(home: sandbox.root))
        let outcome = await remover.remove([RemovalRequest(url: sandbox.url("Library/Caches/gone"), size: 5_000, mode: .delete)])
        #expect(outcome.freed == 0)
        #expect(outcome.failures.isEmpty)
    }

    @Test func shellQuotingSurvivesHostileNames() async throws {
        let name = "it's a \"test\" $(rm -rf ~)"
        let result = try await Shell.run("/bin/sh", ["-c", "printf %s \(Shell.quote(name))"])
        #expect(result.stdout == name)
    }

    @Test func systemReadingsAreSane() throws {
        let memory = try #require(MemoryStats.read())
        #expect(memory.total > 0)
        #expect(memory.used > 0 && memory.used <= memory.total)

        let disk = try #require(DiskStats.read())
        #expect(disk.total > disk.available)
        #expect(disk.available >= disk.free)

        var cpu = CPUSampler()
        let first = cpu.sample()
        #expect(first == nil)
        let second = cpu.sample()
        let load = try #require(second)
        #expect((0...1).contains(load.total))

        var network = NetworkSampler()
        let rate = network.sample()
        #expect(rate == nil)

        var processes = ProcessSampler()
        let list = processes.sample()
        #expect(list.contains { $0.pid == getpid() })
    }
}

struct ShellTests {
    @Test(.timeLimit(.minutes(1)))
    func largeOutputOnBothStreamsDoesNotDeadlock() async throws {
        // 1 MB on stdout and 200 KB on stderr: far past the 64 KB pipe buffer.
        let script = "head -c 1000000 /dev/zero | tr '\\\\0' a; head -c 200000 /dev/zero | tr '\\\\0' b >&2"
        let result = try await Shell.run("/bin/sh", ["-c", script])
        #expect(result.stdout.count == 1_000_000)
        #expect(result.stderr.count == 200_000)
        #expect(result.succeeded)
    }
}
