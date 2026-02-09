import SwiftUI

struct ContentView: View {
    @State private var viewModel = ScanViewModel()

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                if viewModel.selectedFilesToDelete.count > 0 {
                    HStack {
                        Label("\(viewModel.selectedFilesToDelete.count) selected for deletion", systemImage: "trash")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text("(\(viewModel.formattedMarkedBytes) to be freed)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)
                }

                sidebar
                    .navigationSplitViewColumnWidth(min: 280, ideal: 300)
            }
        } detail: {
            detailView
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            FolderPickerView(viewModel: viewModel)
                .padding()

            Divider()

            if viewModel.isScanning {
                ScanProgressView(viewModel: viewModel)
                    .padding()
            } else if viewModel.hasResults {
                DuplicateListView(viewModel: viewModel)
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let group = viewModel.selectedGroup {
            ComparisonView(viewModel: viewModel, group: group)
        } else if viewModel.hasResults {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Select a duplicate group to compare")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.isScanning {
            scanDetailView
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 64))
                    .foregroundStyle(.tertiary)
                Text("Cull")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text("Select a folder to scan for duplicate photos")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scanDetailView: some View {
        VStack(spacing: 20) {
            Spacer()

            switch viewModel.scanProgress.phase {
            case .discovering:
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("\(viewModel.scanProgress.discoveredFiles)")
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.default, value: viewModel.scanProgress.discoveredFiles)
                Text("photos discovered")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(viewModel.scanProgress.currentFileName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)

            case .hashing(let processed, let total, let name):
                LighthouseView()
                Text("\(processed) / \(total)")
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.default, value: processed)
                Text("photos analyzed")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(processed), total: Double(total))
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 300)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)

            default:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Processing...")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No scan results")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Pick a folder and start scanning")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// Option 3: Duplicate documents icon
struct LighthouseView: View {
    var body: some View {
        Image(systemName: "doc.on.doc.fill")
            .font(.system(size: 48))
            .foregroundStyle(.blue)
    }
}
