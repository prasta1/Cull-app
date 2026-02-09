import Foundation

struct DuplicateGroup: Identifiable {
    let id = UUID()
    var files: [PhotoFile]
    let matchType: MatchType
    let similarity: Double

    enum MatchType: String, CaseIterable {
        case exact = "Exact Match"
        case perceptual = "Visual Match"
    }

    var fileCount: Int {
        files.count
    }

    var wastedBytes: UInt64 {
        guard files.count > 1 else { return 0 }
        let sorted = files.sorted { $0.fileSize > $1.fileSize }
        return sorted.dropFirst().reduce(0) { $0 + $1.fileSize }
    }

    var formattedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(wastedBytes), countStyle: .file)
    }
}
