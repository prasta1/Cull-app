import Foundation
import AppKit

struct PhotoFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let fileSize: UInt64
    let modificationDate: Date?
    let creationDate: Date?
    var sha256Hash: String?
    var perceptualHash: UInt64?
    var pixelWidth: Int?
    var pixelHeight: Int?

    var fileName: String {
        url.lastPathComponent
    }

    var filePath: String {
        url.path
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    var dimensions: String? {
        guard let w = pixelWidth, let h = pixelHeight else { return nil }
        return "\(w) x \(h)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoFile, rhs: PhotoFile) -> Bool {
        lhs.id == rhs.id
    }
}
