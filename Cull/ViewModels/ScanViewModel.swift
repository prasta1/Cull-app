import Foundation
import SwiftUI
import AppKit

@Observable
@MainActor
final class ScanViewModel {
    var settings = ScanSettings()
    var scanProgress = ScanProgress()
    var duplicateGroups: [DuplicateGroup] = []
    var selectedGroup: DuplicateGroup?
    var selectedFilesToDelete: Set<UUID> = Set()
    var isScanning = false
    var errorMessage: String?
    var showError = false
    var showDeleteConfirmation = false
    var isDeleting = false

    private let engine = DuplicateEngine()
    private var scanTask: Task<Void, Never>?
    private var folderAccessActive = false

    var totalWastedSpace: String {
        let total = duplicateGroups.reduce(UInt64(0)) { $0 + $1.wastedBytes }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    var totalDuplicates: Int {
        duplicateGroups.reduce(0) { $0 + $1.fileCount - 1 }
    }

    var hasResults: Bool {
        !duplicateGroups.isEmpty
    }

    var progressFraction: Double {
        if case .hashing(let processed, let total, _) = scanProgress.phase, total > 0 {
            return Double(processed) / Double(total)
        }
        return 0
    }

    var progressMessage: String {
        switch scanProgress.phase {
        case .idle:
            return "Ready to scan"
        case .discovering:
            return "Discovering files... (\(scanProgress.discoveredFiles) found)"
        case .hashing(let processed, let total, let name):
            return "Analyzing \(processed)/\(total): \(name)"
        case .grouping:
            // Show detected duplicate groups count during grouping phase
            return "Grouping duplicates... found \(scanProgress.partialDuplicateGroups) groups so far"
        case .complete:
            return "Scan complete"
        case .failed(let msg):
            return "Error: \(msg)"
        }
    }
    
    var partialDuplicateGroupsCount: Int {
        scanProgress.partialDuplicateGroups
    }

    var deleteConfirmationMessage: String {
        let count = selectedFilesToDelete.count
        let isNetwork = settings.folderURL?.path.hasPrefix("/Volumes/") == true
        if isNetwork {
            return "Permanently delete \(count) file\(count == 1 ? "" : "s")? These are on a network volume and cannot be moved to Trash."
        }
        return "Move \(count) file\(count == 1 ? "" : "s") to Trash?"
    }

    var allFilesMarkedForDeletion: [PhotoFile] {
        duplicateGroups.flatMap { group in
            group.files.filter { selectedFilesToDelete.contains($0.id) }
        }
    }
    
    var totalMarkedBytes: UInt64 {
        allFilesMarkedForDeletion.reduce(0) { $0 + $1.fileSize }
    }
    
    var formattedMarkedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMarkedBytes), countStyle: .file)
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to scan for duplicate photos"
        panel.prompt = "Scan"

        if panel.runModal() == .OK, let url = panel.url {
            // Release previous access if active
            stopFolderAccess()

            settings.folderURL = url

            // Create security-scoped bookmark
            do {
                let bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                settings.securityScopedBookmark = bookmark
            } catch {
                // Non-fatal: we can still use the URL for this session
            }

            // Start and keep access alive for the session
            startFolderAccess()
        }
    }

    private func startFolderAccess() {
        guard let url = resolvedFolderURL(), !folderAccessActive else { return }
        folderAccessActive = url.startAccessingSecurityScopedResource()
    }

    private func stopFolderAccess() {
        guard folderAccessActive, let url = settings.folderURL else { return }
        url.stopAccessingSecurityScopedResource()
        folderAccessActive = false
    }

    private func resolvedFolderURL() -> URL? {
        // Try bookmark first for persisted access
        if let bookmark = settings.securityScopedBookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    settings.securityScopedBookmark = try? url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                }
                return url
            }
        }
        return settings.folderURL
    }

    func startScan() {
        guard let folderURL = settings.folderURL else { return }

        isScanning = true
        scanProgress = ScanProgress()
        duplicateGroups = []
        selectedGroup = nil
        selectedFilesToDelete = []
        errorMessage = nil

        // Reset partialDuplicateGroups count to 0 at start
        scanProgress.partialDuplicateGroups = 0

        // Ensure folder access is active
        startFolderAccess()

        scanTask = Task {
            do {
                let groups = try await engine.scan(
                    folder: folderURL,
                    mode: settings.scanMode,
                    hammingThreshold: settings.hammingDistanceThreshold
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.scanProgress = progress
                    }
                }

                self.duplicateGroups = groups
                // Update partialDuplicateGroups to final count at scan completion
                self.scanProgress.partialDuplicateGroups = groups.count
                self.isScanning = false
            } catch is CancellationError {
                self.isScanning = false
                self.scanProgress.phase = .idle
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isScanning = false
                self.scanProgress.phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress.phase = .idle
    }

    func toggleFileForDeletion(_ file: PhotoFile) {
        if selectedFilesToDelete.contains(file.id) {
            selectedFilesToDelete.remove(file.id)
        } else {
            // Don't allow selecting all files in a group for deletion
            if let group = selectedGroup {
                let wouldBeSelected = selectedFilesToDelete.union([file.id])
                let groupIDs = Set(group.files.map(\.id))
                if wouldBeSelected.isSuperset(of: groupIDs) {
                    return // Can't delete all files
                }
            }
            selectedFilesToDelete.insert(file.id)
        }
    }

    func selectAllButLargest(in group: DuplicateGroup) {
        let sorted = group.files.sorted { $0.fileSize > $1.fileSize }
        selectedFilesToDelete = Set(sorted.dropFirst().map(\.id))
    }

    func requestDelete() {
        guard !selectedFilesToDelete.isEmpty else { return }
        showDeleteConfirmation = true
    }

    func deleteSelectedFiles() async {
        guard let group = selectedGroup else { return }

        isDeleting = true
        let filesToDelete = group.files.filter { selectedFilesToDelete.contains($0.id) }
        var deletedIDs = Set<UUID>()
        var failedFiles: [(name: String, error: String)] = []

        // Delete files concurrently using TaskGroup
        await withTaskGroup(of: (UUID, String?, String?).self) { taskGroup in
            for file in filesToDelete {
                taskGroup.addTask {
                    // Try trashItem first (works on local volumes)
                    do {
                        try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                        return (file.id, nil, nil)
                    } catch {
                        // trashItem failed -- likely a network volume
                    }

                    // Fall back to permanent delete for network volumes
                    do {
                        try FileManager.default.removeItem(at: file.url)
                        return (file.id, nil, nil)
                    } catch {
                        return (file.id, file.fileName, error.localizedDescription)
                    }
                }
            }

            // Collect results from all deletion tasks
            for await (fileID, fileName, errorMsg) in taskGroup {
                if let fileName = fileName, let errorMsg = errorMsg {
                    failedFiles.append((fileName, errorMsg))
                } else {
                    deletedIDs.insert(fileID)
                }
            }
        }

        if !failedFiles.isEmpty {
            let details = failedFiles.map { "\($0.name): \($0.error)" }.joined(separator: "\n")
            errorMessage = "Failed to delete \(failedFiles.count) file(s):\n\(details)"
            showError = true
        }

        // Update the group - only remove successfully deleted files
        if !deletedIDs.isEmpty {
            if let index = duplicateGroups.firstIndex(where: { $0.id == group.id }) {
                duplicateGroups[index].files.removeAll { deletedIDs.contains($0.id) }
                if duplicateGroups[index].files.count <= 1 {
                    duplicateGroups.remove(at: index)
                    selectedGroup = nil
                } else {
                    selectedGroup = duplicateGroups[index]
                }
            }
        }

        selectedFilesToDelete = []
        isDeleting = false
    }

}
