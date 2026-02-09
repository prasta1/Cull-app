import Foundation
import CoreGraphics
import AppKit
import ImageIO

struct PerceptualHashService: Sendable {
    private static let hashWidth = 9
    private static let hashHeight = 8

    func dHash(of url: URL) -> UInt64? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }

        guard let grayscale = resizeToGrayscale(cgImage, width: Self.hashWidth, height: Self.hashHeight) else {
            return nil
        }

        return computeDHash(from: grayscale, width: Self.hashWidth, height: Self.hashHeight)
    }

    func imageDimensions(of url: URL) -> (width: Int, height: Int)? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return (width, height)
    }

    private func resizeToGrayscale(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
        return Array(UnsafeBufferPointer(start: buffer, count: width * height))
    }

    private func computeDHash(from pixels: [UInt8], width: Int, height: Int) -> UInt64 {
        var hash: UInt64 = 0
        var bit = 0

        for row in 0..<height {
            for col in 0..<(width - 1) {
                let leftPixel = pixels[row * width + col]
                let rightPixel = pixels[row * width + col + 1]
                if leftPixel > rightPixel {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }

        return hash
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        return (a ^ b).nonzeroBitCount
    }

    func findPerceptualDuplicates(
        in files: [PhotoFile],
        threshold: Int,
        progressHandler: @Sendable (Int, Int, String) -> Void
    ) async throws -> [DuplicateGroup] {
        var hashedFiles: [PhotoFile] = []
        let total = files.count

        for (index, var file) in files.enumerated() {
            try Task.checkCancellation()
            progressHandler(index + 1, total, file.fileName)

            if let hash = dHash(of: file.url) {
                file.perceptualHash = hash
                if let dims = imageDimensions(of: file.url) {
                    file.pixelWidth = dims.width
                    file.pixelHeight = dims.height
                }
                hashedFiles.append(file)
            }
        }

        return clusterByHammingDistance(hashedFiles, threshold: threshold)
    }

    private func clusterByHammingDistance(_ files: [PhotoFile], threshold: Int) -> [DuplicateGroup] {
        var visited = Set<UUID>()
        var groups: [DuplicateGroup] = []

        for i in 0..<files.count {
            guard !visited.contains(files[i].id) else { continue }
            guard let hashA = files[i].perceptualHash else { continue }

            var group = [files[i]]
            visited.insert(files[i].id)

            for j in (i + 1)..<files.count {
                guard !visited.contains(files[j].id) else { continue }
                guard let hashB = files[j].perceptualHash else { continue }

                let distance = Self.hammingDistance(hashA, hashB)
                if distance <= threshold {
                    group.append(files[j])
                    visited.insert(files[j].id)
                }
            }

            if group.count > 1 {
                let avgDistance = group.count > 1 ? Double(threshold) / 64.0 : 0
                let similarity = 1.0 - avgDistance
                groups.append(DuplicateGroup(
                    files: group,
                    matchType: .perceptual,
                    similarity: similarity
                ))
            }
        }

        return groups
    }
}
