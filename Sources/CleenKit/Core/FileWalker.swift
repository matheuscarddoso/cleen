import Darwin
import Foundation

/// A fast, allocation-light directory walker built on `fts(3)`.
///
/// FileManager's enumerator costs an object per entry and is several times slower on
/// trees with millions of files (a home folder, `node_modules`). `fts` hands back the
/// `stat` it already did, so sizes come for free. The walk never follows symlinks and
/// never crosses into another volume.
public enum FileWalker {
    public enum Decision {
        case proceed
        /// Don't descend into this directory. Only meaningful for `.directory` entries.
        case skipChildren
        case stop
    }

    /// Walks `root` depth-first. Directories are reported twice: `.directory` before their
    /// children and `.directoryEnd` after them, which makes post-order aggregation trivial.
    public static func walk(_ root: URL, visit: (WalkEntry) -> Decision) {
        let path = strdup(root.path(percentEncoded: false))
        defer { free(path) }
        var paths: [UnsafeMutablePointer<CChar>?] = [path, nil]
        guard let fts = fts_open(&paths, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR, nil) else { return }
        defer { fts_close(fts) }

        while let raw = fts_read(fts) {
            let entry = WalkEntry(raw: raw)
            guard entry.kind != .ignored else { continue }
            switch visit(entry) {
            case .proceed:
                continue
            case .skipChildren:
                if entry.kind == .directory { fts_set(fts, raw, FTS_SKIP) }
            case .stop:
                return
            }
        }
    }
}

/// One entry produced by ``FileWalker``. Valid only inside the visit closure.
public struct WalkEntry {
    public enum Kind: Equatable {
        case file
        case directory
        case directoryEnd
        case symlink
        case unreadable
        case ignored
    }

    let raw: UnsafeMutablePointer<FTSENT>

    public var kind: Kind {
        switch Int32(raw.pointee.fts_info) {
        case FTS_F, FTS_DEFAULT: .file
        case FTS_D: .directory
        case FTS_DP: .directoryEnd
        case FTS_SL, FTS_SLNONE: .symlink
        case FTS_DNR, FTS_ERR, FTS_NS: .unreadable
        default: .ignored // FTS_DC (cycle), FTS_DOT
        }
    }

    public var path: String { String(cString: raw.pointee.fts_path) }

    public var name: String {
        let offset = Int(raw.pointee.fts_pathlen) - Int(raw.pointee.fts_namelen)
        return String(cString: raw.pointee.fts_path + offset)
    }

    /// Depth below the root, which is level 0.
    public var level: Int { Int(raw.pointee.fts_level) }

    private var stat: Darwin.stat? { raw.pointee.fts_statp?.pointee }

    /// Bytes actually allocated on disk — what deleting this entry frees. Sparse files and
    /// iCloud placeholders report far less than their logical size, which is the point.
    public var allocatedSize: Int64 {
        guard let stat else { return 0 }
        return Int64(stat.st_blocks) * 512
    }

    public var logicalSize: Int64 { Int64(stat?.st_size ?? 0) }

    public var modified: Date {
        Date(timeIntervalSince1970: TimeInterval(stat?.st_mtimespec.tv_sec ?? 0))
    }

    public var accessed: Date {
        Date(timeIntervalSince1970: TimeInterval(stat?.st_atimespec.tv_sec ?? 0))
    }

    /// Identity of the underlying inode, used to count hard-linked files once.
    public var inode: FileIdentity? {
        guard let stat else { return nil }
        return FileIdentity(device: Int64(stat.st_dev), inode: stat.st_ino)
    }

    public var linkCount: Int { Int(stat?.st_nlink ?? 1) }

    /// An iCloud file whose contents were evicted. Reading it would trigger a download.
    public var isDataless: Bool {
        guard let stat else { return false }
        return stat.st_flags & UInt32(SF_DATALESS) != 0
    }
}

public struct FileIdentity: Hashable, Sendable {
    public let device: Int64
    public let inode: UInt64
}
