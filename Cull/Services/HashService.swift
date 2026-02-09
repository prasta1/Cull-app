import Foundation
import CryptoKit

struct HashService: Sendable {
    func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func groupBySize(_ files: [PhotoFile]) -> [[PhotoFile]] {
        var sizeMap: [UInt64: [PhotoFile]] = [:]
        for file in files {
            sizeMap[file.fileSize, default: []].append(file)
        }
        return sizeMap.values.filter { $0.count > 1 }
    }

    func findExactDuplicates(
        in files: [PhotoFile],
        progressHandler: @Sendable (Int, Int, String) -> Void
    ) async throws -> [DuplicateGroup] {
        let sizeGroups = groupBySize(files)
        let candidateFiles = sizeGroups.flatMap { $0 }

        var hashMap: [String: [PhotoFile]] = [:]
        var processed = 0
        let total = candidateFiles.count

        for var file in candidateFiles {
            try Task.checkCancellation()
            processed += 1
            progressHandler(processed, total, file.fileName)

            do {
                let hash = try sha256(of: file.url)
                file.sha256Hash = hash
                hashMap[hash, default: []].append(file)
            } catch {
                continue
            }
        }

        return hashMap.values
            .filter { $0.count > 1 }
            .map { group in
                DuplicateGroup(
                    files: group,
                    matchType: .exact,
                    similarity: 1.0
                )
            }
    }
}
