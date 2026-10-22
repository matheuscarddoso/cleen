import Foundation

public struct SpaceLensScanner: Sendable {
    public struct Progress: Sendable {
        public let items: Int
        public let bytes: Int64
        public let path: String
    }

    public struct Result: Sendable {
        public let root: SpaceNode
        /// Folders that couldn't be read (usually: no Full Disk Access).
        public let unreadable: Int
    }

    let root: URL
    let minimumNodeSize: Int64

    public init(root: URL, minimumNodeSize: Int64 = 5_000_000) {
        self.root = root
        self.minimumNodeSize = minimumNodeSize
    }

    private struct Builder {
        let path: String
        let name: String
        var size: Int64
        var children: [SpaceNode] = []
        var foldedSize: Int64 = 0
        var foldedCount = 0
    }

    public func scan(progress: @Sendable (Progress) -> Void = { _ in }) -> Result? {
        var stack: [Builder] = []
        var result: SpaceNode?
        var seenLinks = Set<FileIdentity>()
        var items = 0
        var bytes: Int64 = 0
        var unreadable = 0

        FileWalker.walk(root) { entry in
            items += 1
            if items % 4096 == 0 {
                if Task.isCancelled { return .stop }
                progress(Progress(items: items, bytes: bytes, path: entry.path))
            }

            switch entry.kind {
            case .directory:
                stack.append(Builder(path: entry.path, name: entry.name, size: entry.allocatedSize))
                bytes += entry.allocatedSize

            case .unreadable where stack.last?.path == entry.path:
                // fts reports a folder it can't list as FTS_D followed by FTS_DNR, with no
                // FTS_DP; close it here or every later entry lands in the wrong parent.
                unreadable += 1
                close(stack.removeLast(), into: &stack, result: &result)

            case .file, .symlink, .unreadable:
                if entry.kind == .unreadable { unreadable += 1 }
                if entry.linkCount > 1, let identity = entry.inode, !seenLinks.insert(identity).inserted {
                    return .proceed
                }
                let size = entry.allocatedSize
                bytes += size
                guard !stack.isEmpty else { return .proceed }
                stack[stack.count - 1].size += size
                if size >= minimumNodeSize {
                    stack[stack.count - 1].children.append(SpaceNode(
                        id: entry.path, name: entry.name, size: size,
                        isDirectory: entry.kind == .unreadable, isAggregate: false, children: []
                    ))
                } else {
                    stack[stack.count - 1].foldedSize += size
                    stack[stack.count - 1].foldedCount += 1
                }

            case .directoryEnd:
                guard let finished = stack.popLast() else { return .proceed }
                close(finished, into: &stack, result: &result)

            case .ignored:
                break
            }
            return .proceed
        }

        // A cancelled walk leaves folders open; close them so the partial map is usable.
        while let open = stack.popLast() {
            let node = finalize(open)
            if stack.isEmpty {
                result = node
            } else {
                stack[stack.count - 1].size += node.size
                stack[stack.count - 1].children.append(node)
            }
        }
        return result.map { Result(root: $0, unreadable: unreadable) }
    }

    private func close(_ finished: Builder, into stack: inout [Builder], result: inout SpaceNode?) {
        let node = finalize(finished)
        guard !stack.isEmpty else {
            result = node
            return
        }
        stack[stack.count - 1].size += node.size
        if node.size >= minimumNodeSize {
            stack[stack.count - 1].children.append(node)
        } else {
            stack[stack.count - 1].foldedSize += node.size
            stack[stack.count - 1].foldedCount += 1
        }
    }

    private func finalize(_ builder: Builder) -> SpaceNode {
        var children = builder.children.sorted { $0.size > $1.size }
        if builder.foldedSize > 0 {
            children.append(SpaceNode(
                id: builder.path + "/\u{0}folded",
                name: builder.foldedCount == 1 ? "1 item menor" : "\(builder.foldedCount) itens menores",
                size: builder.foldedSize,
                isDirectory: false,
                isAggregate: true,
                children: []
            ))
        }
        return SpaceNode(
            id: builder.path,
            name: builder.name,
            size: builder.size,
            isDirectory: true,
            isAggregate: false,
            children: children
        )
    }
}
