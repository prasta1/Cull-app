import SwiftUI

struct ScanProgressView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.scanProgress.phase {
            case .hashing(let processed, let total, _):
                ProgressView(value: Double(processed), total: Double(total)) {
                    Text("Analyzing photos...")
                        .font(.headline)
                }
                .progressViewStyle(.linear)

                HStack {
                    Text("\(processed)")
                        .font(.title2.monospacedDigit())
                        .fontWeight(.semibold)
                    Text("of \(total) scanned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Duplicates found: \(viewModel.duplicateGroups.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(viewModel.scanProgress.currentFileName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

            case .discovering:
                ProgressView()
                    .progressViewStyle(.linear)

                HStack {
                    Text("\(viewModel.scanProgress.discoveredFiles)")
                        .font(.title2.monospacedDigit())
                        .fontWeight(.semibold)
                    Text("photos found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Duplicates found: \(viewModel.duplicateGroups.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(viewModel.scanProgress.currentFileName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

            default:
                ProgressView {
                    Text(viewModel.progressMessage)
                        .font(.headline)
                }
                .progressViewStyle(.linear)
            }

            Button("Cancel") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
