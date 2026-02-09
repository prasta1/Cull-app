import SwiftUI

struct DuplicateGroupRow: View {
    let group: DuplicateGroup

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail strip (show first 3)
            HStack(spacing: -8) {
                ForEach(Array(group.files.prefix(3).enumerated()), id: \.element.id) { index, file in
                    ThumbnailView(url: file.url, size: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.background, lineWidth: 2)
                        )
                        .zIndex(Double(3 - index))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(group.fileCount) files")
                        .font(.headline)
                    matchBadge
                }
                Text(group.formattedWastedSpace + " wasted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var matchBadge: some View {
        Text(group.matchType.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                group.matchType == .exact
                    ? Color.green.opacity(0.2)
                    : Color.orange.opacity(0.2)
            )
            .foregroundStyle(
                group.matchType == .exact ? .green : .orange
            )
            .clipShape(Capsule())
    }
}
