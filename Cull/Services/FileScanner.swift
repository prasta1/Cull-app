import Foundation
import UniformTypeIdentifiers

struct FileScanner: Sendable {
    private static let supportedExtensions: Set<String> = ["jpg", "jpeg", "heic", "png"]

    func scanDirectory(
        at url: URL,
        progressHandler: @Sendable (Int, String) -> Void
    ) async throws -> [PhotoFile] {
        var results: [PhotoFile] = []
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isRegularFileKey,
            .typeIdentifierKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ScanError.cannotAccessDirectory(url.path)
        }

        let allURLs = enumerator.compactMap { $0 as? URL }
        var count = 0
        for fileURL in allURLs {
            try Task.checkCancellation()

            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  resourceValues.isRegularFile == true,
                  let fileSize = resourceValues.fileSize,
                  fileSize > 0 else {
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            guard Self.supportedExtensions.contains(ext) else { continue }

            count += 1
            progressHandler(count, fileURL.lastPathComponent)

            let photo = PhotoFile(
                url: fileURL,
                fileSize: UInt64(fileSize),
                modificationDate: resourceValues.contentModificationDate,
                creationDate: resourceValues.creationDate
            )
            results.append(photo)
        }

        return results
    }
}

enum ScanError: LocalizedError {
    case cannotAccessDirectory(String)
    case hashingFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cannotAccessDirectory(let path):
            return "Cannot access directory: \(path)"
        case .hashingFailed(let file):
            return "Failed to hash file: \(file)"
        case .cancelled:
            return "Scan was cancelled"
        }
    }
}
