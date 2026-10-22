import Foundation
import LustroKit

/// What the disk map covers.
enum SpaceTarget: Hashable {
    case home
    /// The whole data volume. `/` itself is the sealed, read-only system snapshot.
    case disk
    case folder(URL)

    var url: URL {
        switch self {
        case .home: Paths.home
        case .disk: URL(filePath: "/System/Volumes/Data", directoryHint: .isDirectory)
        case .folder(let url): url
        }
    }

    var title: String {
        switch self {
        case .home: "Sua pasta pessoal"
        case .disk: "Disco inteiro"
        case .folder(let url): url.lastPathComponent
        }
    }
}
