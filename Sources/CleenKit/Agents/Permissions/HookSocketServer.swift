import Darwin
import Dispatch
import Foundation

/// The local end of Cleen's hook: a Unix socket the hook script posts each request to,
/// held open until the person answers. Only this user's processes can reach it (the
/// socket is 0600 inside `~/Library`, and each peer's uid is checked).
///
/// Everything runs on one serial queue; the callbacks are called there too.
public final class HookSocketServer: @unchecked Sendable {
    public enum StartError: Error, Equatable {
        /// Another Cleen is already listening.
        case inUse
        case pathTooLong
        case system(String)
    }

    public let path: String
    /// How long a request waits for an answer before it's given back unanswered.
    public let lifetime: TimeInterval
    private let onRequest: @Sendable (UUID, Data) -> Void
    private let onGone: @Sendable (UUID) -> Void

    private let queue = DispatchQueue(label: "app.cleen.agent-socket")
    private var listener: DispatchSourceRead?
    private var clients: [UUID: Client] = [:]

    /// The largest request read: a `Write` carries the whole file in its input.
    static let maximumRequest = 16 << 20

    /// `onRequest` gets each request's JSON body; answer it with `respond`. `onGone`
    /// says a request ended without an answer from Cleen: the hook gave up, Claude Code
    /// moved on (answered in the terminal), or it outlived `lifetime`.
    public init(path: String, lifetime: TimeInterval, onRequest: @escaping @Sendable (UUID, Data) -> Void, onGone: @escaping @Sendable (UUID) -> Void) {
        self.path = path
        self.lifetime = lifetime
        self.onRequest = onRequest
        self.onGone = onGone
    }

    deinit {
        listener?.cancel()
    }

    // MARK: Lifecycle

    public func start() throws(StartError) {
        var result: Result<Void, StartError> = .success(())
        queue.sync { result = Result { () throws(StartError) in try listen() } }
        try result.get()
    }

    /// Stops listening and hands every waiting request back unanswered, so each
    /// terminal shows its own prompt right away.
    public func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
            for id in Array(clients.keys) { finish(id, body: nil, notify: true) }
            unlink(path)
        }
    }

    /// The answer for one request: the hook prints `body` for Claude Code, or nothing
    /// when it's `nil` (Claude Code then asks in the terminal).
    public func respond(_ id: UUID, body: Data?) {
        queue.async { self.finish(id, body: body, notify: false) }
    }

    private func listen() throws(StartError) {
        guard listener == nil else { return }
        guard path.utf8.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) else { throw .pathTooLong }
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)

        // A socket file left by a Cleen that crashed answers nothing; one that answers
        // belongs to a Cleen that's still running.
        if FileManager.default.fileExists(atPath: path) {
            if Self.isListening(path) { throw .inUse }
            unlink(path)
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw .system(Self.errnoText) }
        var address = Self.address(path)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, chmod(path, 0o600) == 0, Darwin.listen(fd, 16) == 0 else {
            let text = Self.errnoText
            close(fd)
            unlink(path)
            throw .system(text)
        }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptAll(fd) }
        source.setCancelHandler { close(fd) }
        source.resume()
        listener = source
    }

    // MARK: Connections

    private final class Client {
        let fd: Int32
        let source: DispatchSourceRead
        var buffer = Data()
        /// Set once the whole request was read and handed to `onRequest`.
        var delivered = false
        var sentContinue = false

        init(fd: Int32, source: DispatchSourceRead) {
            self.fd = fd
            self.source = source
        }
    }

    private func acceptAll(_ listenFD: Int32) {
        while true {
            let fd = accept(listenFD, nil, nil)
            guard fd >= 0 else { return }
            var uid: uid_t = 0
            var gid: gid_t = 0
            guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { close(fd); continue }
            var on: Int32 = 1
            // A hook that's gone must not take Cleen down with SIGPIPE on the reply.
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

            let id = UUID()
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            clients[id] = Client(fd: fd, source: source)
            source.setEventHandler { [weak self] in self?.read(id) }
            source.setCancelHandler { close(fd) }
            source.resume()

            // A request that never finishes arriving isn't one.
            queue.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self, let client = self.clients[id], !client.delivered else { return }
                self.finish(id, body: nil, notify: false)
            }
        }
    }

    private func read(_ id: UUID) {
        guard let client = clients[id] else { return }
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = Darwin.read(client.fd, &chunk, chunk.count)
            if count > 0 {
                // Past the request, the hook sends nothing more; only its closing matters.
                if !client.delivered { client.buffer.append(contentsOf: chunk[0..<count]) }
                continue
            }
            if count < 0, errno == EAGAIN || errno == EINTR { break }
            // Closed (or broken): the hook is gone, whatever it was waiting for.
            finish(id, body: nil, notify: client.delivered)
            return
        }
        guard !client.delivered else { return }
        guard client.buffer.count <= Self.maximumRequest else { finish(id, body: nil, notify: false); return }
        switch HookHTTP.parse(client.buffer) {
        case .incomplete(let expectsContinue):
            if expectsContinue, !client.sentContinue {
                client.sentContinue = true
                write(client.fd, Data("HTTP/1.1 100 Continue\r\n\r\n".utf8))
            }
        case .invalid:
            finish(id, body: nil, notify: false)
        case .complete(let body):
            client.delivered = true
            client.buffer = Data()
            onRequest(id, body)
            queue.asyncAfter(deadline: .now() + lifetime) { [weak self] in
                guard let self, self.clients[id] != nil else { return }
                self.finish(id, body: nil, notify: true)
            }
        }
    }

    /// Answers (or not) and lets go of the connection.
    private func finish(_ id: UUID, body: Data?, notify: Bool) {
        guard let client = clients.removeValue(forKey: id) else { return }
        write(client.fd, HookHTTP.response(body: body))
        client.source.cancel()
        if notify { onGone(id) }
    }

    private func write(_ fd: Int32, _ data: Data) {
        data.withUnsafeBytes { raw in
            guard var pointer = raw.baseAddress else { return }
            var left = raw.count
            var stalls = 0
            while left > 0 {
                let sent = Darwin.write(fd, pointer, left)
                if sent > 0 {
                    pointer += sent
                    left -= sent
                } else if sent < 0, errno == EAGAIN || errno == EINTR, stalls < 200 {
                    // Replies are a few hundred bytes; a full buffer clears in moments.
                    stalls += 1
                    usleep(1000)
                } else {
                    return
                }
            }
        }
    }

    // MARK: Helpers

    private static func address(_ path: String) -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            let bytes = Array(path.utf8.prefix(buffer.count - 1))
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        return address
    }

    static func isListening(_ path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var address = address(path)
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        } == 0
    }

    private static var errnoText: String { String(cString: strerror(errno)) }
}

/// Just enough HTTP for one client, `curl`: a POST with a body in, a reply out.
enum HookHTTP {
    enum Parsed: Equatable {
        case incomplete(expectsContinue: Bool)
        case complete(Data)
        case invalid
    }

    static func parse(_ buffer: Data) -> Parsed {
        let separator = Data("\r\n\r\n".utf8)
        guard let end = buffer.range(of: separator) else {
            return buffer.count > 64 * 1024 ? .invalid : .incomplete(expectsContinue: false)
        }
        let head = String(decoding: buffer[buffer.startIndex..<end.lowerBound], as: UTF8.self)
        let lines = head.components(separatedBy: "\r\n")
        guard let request = lines.first, request.hasPrefix("POST ") else { return .invalid }
        var length: Int?
        var expectsContinue = false
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if name == "content-length" { length = Int(value) }
            if name == "expect", value.lowercased() == "100-continue" { expectsContinue = true }
            if name == "transfer-encoding" { return .invalid }
        }
        guard let length, length >= 0 else { return .invalid }
        let body = buffer[end.upperBound...]
        guard body.count >= length else { return .incomplete(expectsContinue: expectsContinue) }
        return .complete(Data(body.prefix(length)))
    }

    /// 200 with the decision, or 204: `curl --fail` prints nothing for it and exits 0.
    static func response(body: Data?) -> Data {
        guard let body, !body.isEmpty else {
            return Data("HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
        }
        var reply = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        reply.append(body)
        return reply
    }
}
