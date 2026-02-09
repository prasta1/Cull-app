import SwiftUI

struct ComparisonView: View {
    @Bindable var viewModel: ScanViewModel
    let group: DuplicateGroup

    @State private var previewURL: URL?

    private func selectAllFiles() {
        // Select all except the largest file (to avoid deleting all copies)
        guard let largestFile = group.files.max(by: { $0.fileSize < $1.fileSize }) else { return }
        let allExceptLargest = group.files.map(\.id).filter { $0 != largestFile.id }
        viewModel.selectedFilesToDelete = Set(allExceptLargest)
    }

    private func deselectAllFiles() {
        viewModel.selectedFilesToDelete.removeAll()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding()

            Divider()

            // Content
            HSplitView {
                // File grid
                fileGrid
                    .frame(minWidth: 300)

                // Preview
                previewPanel
                    .frame(minWidth: 300)
            }

            Divider()

            // Action bar
            actionBar
                .padding()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(group.fileCount) Duplicate Photos")
                    .font(.title2)
                    .fontWeight(.semibold)
                HStack(spacing: 16) {
                    Label(group.matchType.rawValue, systemImage: group.matchType == .exact ? "checkmark.seal" : "eye")
                    Label(group.formattedWastedSpace + " wasted", systemImage: "externaldrive")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Select All But Largest") {
                viewModel.selectAllButLargest(in: group)
            }
            .buttonStyle(.bordered)

            Button("Select All") {
                selectAllFiles()
            }
            .buttonStyle(.bordered)

            Button("Deselect All") {
                deselectAllFiles()
            }
            .buttonStyle(.bordered)
        }
    }

    private var fileGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200), spacing: 12)
            ], spacing: 12) {
                ForEach(group.files) { file in
                    fileCard(file)
                }
            }
            .padding()
        }
    }

    private func fileCard(_ file: PhotoFile) -> some View {
        let isSelected = viewModel.selectedFilesToDelete.contains(file.id)

        return VStack(spacing: 0) {
            // Thumbnail
            ThumbnailView(url: file.url, size: 160)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
                .onTapGesture {
                    previewURL = file.url
                }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack {
                    Text(file.formattedFileSize)
                    if let dims = file.dimensions {
                        Text("  \(dims)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Text(file.url.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)

                // Selection toggle
                HStack {
                    Button {
                        viewModel.toggleFileForDeletion(file)
                    } label: {
                        Label(
                            isSelected ? "Marked for deletion" : "Keep",
                            systemImage: isSelected ? "trash.fill" : "checkmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(isSelected ? .red : .green)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    } label: {
                        Image(systemName: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
                .padding(.top, 4)
            }
            .padding(8)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.red.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .opacity(isSelected ? 0.7 : 1.0)
        .onTapGesture {
            viewModel.toggleFileForDeletion(file)
        }
    }

    @ViewBuilder
    private var previewPanel: some View {
        if let url = previewURL {
            VStack {
                ThumbnailView(url: url, size: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()

                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack {
                Spacer()
                Text("Click a photo to preview")
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var actionBar: some View {
        HStack {
            let count = viewModel.selectedFilesToDelete.count
            Text("\(count) file\(count == 1 ? "" : "s") selected for deletion")
                .foregroundStyle(.secondary)
                .fontWeight(.bold)
                .accentColor(.blue)

            Spacer()

            if viewModel.isDeleting {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }

            Button("Delete Selected", role: .destructive) {
                viewModel.requestDelete()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.selectedFilesToDelete.isEmpty || viewModel.isDeleting)
        }
        .confirmationDialog(
            "Delete Files",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSelectedFiles()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.deleteConfirmationMessage)
        }
    }
}
