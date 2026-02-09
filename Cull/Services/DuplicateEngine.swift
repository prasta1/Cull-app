import Foundation

enum ScanPhase: Sendable {
    case idle
    case discovering
    case hashing(processed: Int, total: Int, currentFile: String)
    case grouping
    case complete
    case failed(String)
}

struct ScanProgress: Sendable {
    var phase: ScanPhase = .idle
    var discoveredFiles: Int = 0
    var currentFileName: String = ""
    var partialDuplicateGroups: Int = 0
}

actor DuplicateEngine {
    private let fileScanner = FileScanner()
    private let hashService = HashService()
    private let perceptualHashService = PerceptualHashService()

    /// Scans the specified folder for duplicate files.
    ///
    /// - Parameters:
    ///   - folder: The folder URL to scan.
    ///   - mode: The scan mode (.exact, .perceptual, .both).
    ///   - hammingThreshold: The threshold for perceptual duplicates.
    ///   - onProgress: Callback reporting current scan progress.
    ///   - onDuplicateCountUpdate: Optional callback reporting the live tally of duplicate groups found so far.
    ///                            This may be called multiple times during hashing/grouping phases.
    /// - Returns: An array of found duplicate groups.
    func scan(
        folder: URL,
        mode: ScanMode,
        hammingThreshold: Int,
        onProgress: @Sendable (ScanProgress) -> Void,
        onDuplicateCountUpdate: (@Sendable (Int) -> Void)? = nil
    ) async throws -> [DuplicateGroup] {
        var progress = ScanProgress()

        // Phase 1: Discover files
        progress.phase = .discovering
        onProgress(progress)

        let files = try await fileScanner.scanDirectory(at: folder) { count, name in
            var p = ScanProgress()
            p.phase = .discovering
            p.discoveredFiles = count
            p.currentFileName = name
            onProgress(p)
        }

        guard !files.isEmpty else { return [] }

        progress.discoveredFiles = files.count

        // Phase 2: Hash and find duplicates based on mode
        var allGroups: [DuplicateGroup] = []

        switch mode {
        case .exact:
            allGroups = try await findExactDuplicates(files: files, onProgress: onProgress, onDuplicateCountUpdate: onDuplicateCountUpdate)
        case .perceptual:
            allGroups = try await findPerceptualDuplicates(
                files: files,
                threshold: hammingThreshold,
                onProgress: onProgress,
                onDuplicateCountUpdate: onDuplicateCountUpdate
            )
        case .both:
            let exactGroups = try await findExactDuplicates(files: files, onProgress: onProgress, onDuplicateCountUpdate: onDuplicateCountUpdate)
            // Report exact count first if possible
            onDuplicateCountUpdate?(exactGroups.count)

            let perceptualGroups = try await findPerceptualDuplicates(
                files: files,
                threshold: hammingThreshold,
                onProgress: onProgress,
                onDuplicateCountUpdate: onDuplicateCountUpdate
            )
            // Merge and update count after merge
            allGroups = mergeGroups(exact: exactGroups, perceptual: perceptualGroups)
            onDuplicateCountUpdate?(allGroups.count)
        }

        // Sort by wasted space descending
        allGroups.sort { $0.wastedBytes > $1.wastedBytes }

        progress.phase = .complete
        onProgress(progress)

        // Final duplicate count update
        onDuplicateCountUpdate?(allGroups.count)

        return allGroups
    }

    private func findExactDuplicates(
        files: [PhotoFile],
        onProgress: @Sendable (ScanProgress) -> Void,
        onDuplicateCountUpdate: (@Sendable (Int) -> Void)? = nil
    ) async throws -> [DuplicateGroup] {
        return try await hashService.findExactDuplicates(in: files) { processed, total, name in
            var p = ScanProgress()
            p.phase = .hashing(processed: processed, total: total, currentFile: name)
            p.discoveredFiles = files.count
            p.currentFileName = name
            onProgress(p)
        }
    }

    private func findPerceptualDuplicates(
        files: [PhotoFile],
        threshold: Int,
        onProgress: @Sendable (ScanProgress) -> Void,
        onDuplicateCountUpdate: (@Sendable (Int) -> Void)? = nil
    ) async throws -> [DuplicateGroup] {
        let groups = try await perceptualHashService.findPerceptualDuplicates(
            in: files,
            threshold: threshold
        ) { processed, total, name in
            var p = ScanProgress()
            p.phase = .hashing(processed: processed, total: total, currentFile: name)
            p.discoveredFiles = files.count
            p.currentFileName = name
            onProgress(p)
        }

        // Report the final count after clustering is complete
        onDuplicateCountUpdate?(groups.count)

        return groups
    }

    private func mergeGroups(exact: [DuplicateGroup], perceptual: [DuplicateGroup]) -> [DuplicateGroup] {
        var merged = exact

        // Track which files are already in exact groups
        var exactFileIDs = Set<UUID>()
        for group in exact {
            for file in group.files {
                exactFileIDs.insert(file.id)
            }
        }

        // Add perceptual groups that don't overlap with exact groups
        for group in perceptual {
            let nonOverlapping = group.files.filter { !exactFileIDs.contains($0.id) }
            if nonOverlapping.count > 1 {
                merged.append(DuplicateGroup(
                    files: nonOverlapping,
                    matchType: .perceptual,
                    similarity: group.similarity
                ))
            }
        }

        return merged
    }
}
