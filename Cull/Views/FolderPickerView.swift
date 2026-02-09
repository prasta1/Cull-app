import SwiftUI

struct FolderPickerView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Folder selection
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
                if let url = viewModel.settings.folderURL {
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No folder selected")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Browse...") {
                    viewModel.pickFolder()
                }
                .disabled(viewModel.isScanning)
            }

            // Scan mode picker
            Picker("Mode:", selection: $viewModel.settings.scanMode) {
                ForEach(ScanMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.isScanning)

            // Threshold slider (only for perceptual modes)
            if viewModel.settings.scanMode != .exact {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Similarity threshold: \(viewModel.settings.hammingDistanceThreshold)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.settings.hammingDistanceThreshold) },
                            set: { viewModel.settings.hammingDistanceThreshold = Int($0) }
                        ),
                        in: 1...20,
                        step: 1
                    )
                    HStack {
                        Text("Strict")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Loose")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Scan button
            HStack {
                if viewModel.isScanning {
                    Button("Cancel") {
                        viewModel.cancelScan()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        viewModel.startScan()
                    } label: {
                        Label("Scan for Duplicates", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.settings.folderURL == nil)
                }
            }

            // Stats summary
            if viewModel.hasResults {
                Divider()
                HStack {
                    Label("\(viewModel.duplicateGroups.count) groups", systemImage: "square.stack.3d.up")
                    Spacer()
                    Label(viewModel.totalWastedSpace, systemImage: "externaldrive")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
