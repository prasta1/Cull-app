import SwiftUI
import AppKit

struct ThumbnailView: View {
    let url: URL
    let size: CGFloat

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: size * 0.3))
                    }
            }
        }
        .task(id: url) {
            image = await loadThumbnail()
        }
    }

    private func loadThumbnail() async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let thumbnailSize = CGSize(width: size * 2, height: size * 2)
                let options: [CFString: Any] = [
                    kCGImageSourceThumbnailMaxPixelSize: max(thumbnailSize.width, thumbnailSize.height),
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]

                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    continuation.resume(returning: nil)
                    return
                }

                let nsImage = NSImage(cgImage: cgImage, size: thumbnailSize)
                continuation.resume(returning: nsImage)
            }
        }
    }
}
