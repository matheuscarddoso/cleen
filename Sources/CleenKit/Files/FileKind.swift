import Foundation
import UniformTypeIdentifiers

public enum FileKind: String, CaseIterable, Sendable, Hashable {
    case video
    case image
    case audio
    case archive
    case installer
    case document
    case other

    public var title: String {
        switch self {
        case .video: String(localized: "Vídeos")
        case .image: String(localized: "Imagens")
        case .audio: String(localized: "Áudio")
        case .archive: String(localized: "Compactados")
        case .installer: String(localized: "Instaladores e imagens de disco")
        case .document: String(localized: "Documentos")
        case .other: String(localized: "Outros")
        }
    }

    public var symbol: String {
        switch self {
        case .video: "film"
        case .image: "photo"
        case .audio: "waveform"
        case .archive: "doc.zipper"
        case .installer: "opticaldiscdrive"
        case .document: "doc.richtext"
        case .other: "doc"
        }
    }

    public init(fileExtension: String) {
        let ext = fileExtension.lowercased()
        if ["dmg", "pkg", "mpkg", "iso", "img", "xip", "ipsw", "sparseimage", "sparsebundle"].contains(ext) {
            self = .installer
            return
        }
        guard let type = UTType(filenameExtension: ext) else {
            self = .other
            return
        }
        self = if type.conforms(to: .movie) || type.conforms(to: .video) {
            .video
        } else if type.conforms(to: .image) {
            .image
        } else if type.conforms(to: .audio) {
            .audio
        } else if type.conforms(to: .archive) || ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst"].contains(ext) {
            .archive
        } else if type.conforms(to: .pdf) || type.conforms(to: .presentation) || type.conforms(to: .spreadsheet)
                    || type.conforms(to: .text) {
            .document
        } else {
            .other
        }
    }
}
