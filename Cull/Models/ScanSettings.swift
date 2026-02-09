import Foundation

enum ScanMode: String, CaseIterable, Identifiable {
    case exact = "Exact Match (SHA256)"
    case perceptual = "Visual Similarity (dHash)"
    case both = "Both"

    var id: String { rawValue }
}

struct ScanSettings {
    var folderURL: URL?
    var scanMode: ScanMode = .both
    var hammingDistanceThreshold: Int = 10
    var securityScopedBookmark: Data?
}
