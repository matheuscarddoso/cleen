import Foundation
import SQLite3
import Testing
@testable import CleenKit

struct MessagesDatabaseTests {
    /// A small chat.db with Messages' own tables and columns (the ones read).
    private func makeDatabase() throws -> (Sandbox, URL) {
        let sandbox = try Sandbox()
        let url = sandbox.url("chat.db")
        var db: OpaquePointer?
        sqlite3_open(url.path(percentEncoded: false), &db)
        defer { sqlite3_close(db) }
        let now = MessagesDatabase.appleTime(.now)
        let body = NSArchiver.archivedData(withRootObject: NSAttributedString(string: "Coffee there Friday?"))
        let sql = """
        CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
        CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT, display_name TEXT, chat_identifier TEXT, style INTEGER);
        CREATE TABLE message (ROWID INTEGER PRIMARY KEY, text TEXT, attributedBody BLOB, date INTEGER, is_from_me INTEGER, is_read INTEGER, handle_id INTEGER, service TEXT, associated_message_type INTEGER DEFAULT 0);
        CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
        CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY, filename TEXT, mime_type TEXT);
        CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);
        INSERT INTO handle VALUES (1, '+5562999990000');
        INSERT INTO chat VALUES (1, 'iMessage;-;+5562999990000', '', '+5562999990000', 45);
        INSERT INTO chat VALUES (2, 'iMessage;+;chat123', 'Família', 'chat123', 43);
        INSERT INTO message VALUES (1, 'Oi', NULL, \(now - 3_000_000_000), 1, 1, 0, 'iMessage', 0);
        INSERT INTO message VALUES (2, NULL, ?, \(now - 2_000_000_000), 0, 0, 1, 'iMessage', 0);
        INSERT INTO message VALUES (3, 'Loved “Oi”', NULL, \(now - 1_500_000_000), 0, 0, 1, 'iMessage', 2000);
        INSERT INTO message VALUES (4, 'Jantar domingo?', NULL, \(now - 1_000_000_000), 0, 0, 1, 'iMessage', 0);
        INSERT INTO chat_message_join VALUES (1, 1), (1, 2), (1, 3), (2, 4);
        """
        // The archived text goes in through a binding; the rest runs as is.
        let parts = sql.components(separatedBy: "INSERT INTO message VALUES (2,")
        sqlite3_exec(db, parts[0], nil, nil, nil)
        var statement: OpaquePointer?
        let second = "INSERT INTO message VALUES (2," + parts[1].components(separatedBy: ";\n")[0]
        sqlite3_prepare_v2(db, second, -1, &statement, nil)
        _ = body.withUnsafeBytes { sqlite3_bind_blob(statement, 1, $0.baseAddress, Int32(body.count), nil) }
        sqlite3_step(statement)
        sqlite3_finalize(statement)
        let rest = parts[1].components(separatedBy: ";\n").dropFirst().joined(separator: ";\n")
        sqlite3_exec(db, rest, nil, nil, nil)
        return (sandbox, url)
    }

    @Test func readsTheLatestConversationsWithTheirUnread() throws {
        let (sandbox, url) = try makeDatabase()
        _ = sandbox
        let database = try #require(MessagesDatabase(url: url))
        let threads = try database.threads()
        #expect(threads.count == 2)
        #expect(threads[0].last.text == "Jantar domingo?" && threads[0].last.isGroup && threads[0].last.chatName == "Família")
        // The archived body is read; the reaction isn't a message.
        #expect(threads[1].last.text == "Coffee there Friday?")
        #expect(threads[1].unread == 1 && threads[1].handle == "+5562999990000")
    }

    @Test func newMessagesAfterAnID() throws {
        let (sandbox, url) = try makeDatabase()
        _ = sandbox
        let database = try #require(MessagesDatabase(url: url))
        #expect(try database.latestID() == 4)
        #expect(try database.messages(after: 1).map(\.id) == [2, 4])
    }

    @Test func noAccessNoDatabase() {
        #expect(MessagesDatabase(url: URL(filePath: "/nonexistent/chat.db")) == nil)
    }
}
