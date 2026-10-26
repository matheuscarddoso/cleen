import Foundation
import SQLite3

/// One message from Messages' own database (`~/Library/Messages/chat.db`), read-only.
public struct ChatMessage: Sendable, Hashable, Identifiable {
    public let id: Int64
    /// The conversation's id, what Messages' scripting takes to reply into it.
    public let chatGUID: String
    /// A group's name, when it has one.
    public let chatName: String?
    /// The sender's phone number or email (nil for one's own messages).
    public let handle: String?
    public let text: String
    public let date: Date
    public let isFromMe: Bool
    public let isGroup: Bool
    /// The first picture sent with it, on disk.
    public let imagePath: String?
    /// "iMessage", "SMS", "RCS".
    public let service: String

    public init(id: Int64, chatGUID: String, chatName: String?, handle: String?, text: String, date: Date, isFromMe: Bool, isGroup: Bool, imagePath: String?, service: String) {
        self.id = id
        self.chatGUID = chatGUID
        self.chatName = chatName
        self.handle = handle
        self.text = text
        self.date = date
        self.isFromMe = isFromMe
        self.isGroup = isGroup
        self.imagePath = imagePath
        self.service = service
    }
}

/// A conversation as the notch lists it: its latest message and how many are unread.
public struct ChatThread: Sendable, Equatable, Identifiable {
    public var id: String { last.chatGUID }
    public let last: ChatMessage
    public let unread: Int
    /// Who it's with (the other person's handle in a one-to-one chat).
    public let handle: String?

    public init(last: ChatMessage, unread: Int, handle: String?) {
        self.last = last
        self.unread = unread
        self.handle = handle
    }
}

/// Reads Messages' database. It needs Full Disk Access; opening fails without it.
/// Reactions (tapbacks) and bookkeeping rows are left out.
public final class MessagesDatabase: @unchecked Sendable {
    public static let defaultURL = URL.homeDirectory.appending(path: "Library/Messages/chat.db")

    private var db: OpaquePointer?

    public init?(url: URL = MessagesDatabase.defaultURL) {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path(percentEncoded: false), &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let handle else {
            if let handle { sqlite3_close(handle) }
            return nil
        }
        // Opening is lazy: a query is what fails without access.
        db = handle
        guard (try? latestID()) != nil else {
            sqlite3_close(handle)
            db = nil
            return nil
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    /// The newest message's id: where to start watching from.
    public func latestID() throws -> Int64 {
        try query("SELECT IFNULL(MAX(ROWID), 0) FROM message") { statement in
            sqlite3_column_int64(statement, 0)
        }.first ?? 0
    }

    /// Messages newer than `id`, oldest first.
    public func messages(after id: Int64, limit: Int = 50) throws -> [ChatMessage] {
        try query(Self.messageSelect + " WHERE m.ROWID > ? AND m.associated_message_type = 0 ORDER BY m.ROWID ASC LIMIT ?", bind: { statement in
            sqlite3_bind_int64(statement, 1, id)
            sqlite3_bind_int(statement, 2, Int32(limit))
        }, row: message)
    }

    /// The latest conversations, newest first.
    public func threads(limit: Int = 6, now: Date = .now) throws -> [ChatThread] {
        let since = Self.appleTime(now.addingTimeInterval(-14 * 86_400))
        let latest = try query(Self.messageSelect + """
             WHERE m.ROWID IN (
                SELECT MAX(j.message_id) FROM chat_message_join j
                JOIN message mm ON mm.ROWID = j.message_id
                WHERE mm.associated_message_type = 0 AND mm.date > ?
                GROUP BY j.chat_id)
             ORDER BY m.date DESC LIMIT ?
            """, bind: { statement in
            sqlite3_bind_int64(statement, 1, since)
            sqlite3_bind_int(statement, 2, Int32(limit))
        }, row: message)
        return try latest.map { last in
            let unread = try query("""
                SELECT COUNT(*) FROM message m
                JOIN chat_message_join j ON j.message_id = m.ROWID
                JOIN chat c ON c.ROWID = j.chat_id
                WHERE c.guid = ? AND m.is_read = 0 AND m.is_from_me = 0 AND m.associated_message_type = 0 AND m.date > ?
                """, bind: { statement in
                sqlite3_bind_text(statement, 1, last.chatGUID, -1, Self.transient)
                sqlite3_bind_int64(statement, 2, since)
            }) { sqlite3_column_int64($0, 0) }.first ?? 0
            let handle = last.isGroup ? nil : (last.handle ?? (try? chatIdentifier(last.chatGUID)))
            return ChatThread(last: last, unread: Int(unread), handle: handle)
        }
    }

    private func chatIdentifier(_ guid: String) throws -> String? {
        try query("SELECT chat_identifier FROM chat WHERE guid = ?", bind: { statement in
            sqlite3_bind_text(statement, 1, guid, -1, Self.transient)
        }) { Self.string($0, 0) }.first ?? nil
    }

    // MARK: Rows

    private static let messageSelect = """
        SELECT m.ROWID, c.guid, c.display_name, h.id, m.text, m.attributedBody, m.date, m.is_from_me, c.style, m.service,
          (SELECT a.filename FROM message_attachment_join maj JOIN attachment a ON a.ROWID = maj.attachment_id
           WHERE maj.message_id = m.ROWID AND a.mime_type LIKE 'image/%' LIMIT 1)
        FROM message m
        JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
        JOIN chat c ON c.ROWID = cmj.chat_id
        LEFT JOIN handle h ON h.ROWID = m.handle_id
        """

    private func message(_ statement: OpaquePointer) -> ChatMessage {
        let plain = Self.string(statement, 4)
        let body = sqlite3_column_blob(statement, 5).map { Data(bytes: $0, count: Int(sqlite3_column_bytes(statement, 5))) }
        let text = (plain?.isEmpty == false ? plain : body.flatMap(Self.text(fromAttributedBody:))) ?? ""
        let image = Self.string(statement, 10).map { ($0 as NSString).expandingTildeInPath }
        return ChatMessage(
            id: sqlite3_column_int64(statement, 0),
            chatGUID: Self.string(statement, 1) ?? "",
            chatName: Self.string(statement, 2).flatMap { $0.isEmpty ? nil : $0 },
            handle: Self.string(statement, 3),
            text: text.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespacesAndNewlines),
            date: Self.date(sqlite3_column_int64(statement, 6)),
            isFromMe: sqlite3_column_int(statement, 7) != 0,
            // Messages' chat style: 43 is a group, 45 one-to-one.
            isGroup: sqlite3_column_int(statement, 8) == 43,
            imagePath: image,
            service: Self.string(statement, 9) ?? "iMessage"
        )
    }

    /// Newer macOS keeps the text only in `attributedBody`, an archived attributed string.
    static func text(fromAttributedBody data: Data) -> String? {
        if let decoded = NSUnarchiver.unarchiveObject(with: data) as? NSAttributedString {
            return decoded.string
        }
        return nil
    }

    // MARK: Time

    /// Messages counts nanoseconds (older databases: seconds) since 2001.
    static func date(_ raw: Int64) -> Date {
        let seconds = raw > 1_000_000_000_000 ? Double(raw) / 1_000_000_000 : Double(raw)
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    static func appleTime(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSinceReferenceDate * 1_000_000_000)
    }

    // MARK: SQLite

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private static func string(_ statement: OpaquePointer, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }

    struct QueryError: Error {}

    private func query<T>(_ sql: String, bind: (OpaquePointer) -> Void = { _ in }, row: (OpaquePointer) -> T) throws -> [T] {
        guard let db else { throw QueryError() }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw QueryError() }
        defer { sqlite3_finalize(statement) }
        bind(statement)
        var rows: [T] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_ROW {
                rows.append(row(statement))
            } else if step == SQLITE_DONE {
                return rows
            } else {
                throw QueryError()
            }
        }
    }
}
