import UIKit
import CoreImage

/// Same pipeline as Android's FaceAlignment.kt: rotation correction ->
/// crop -> resize -> normalize -> tensor. Using one shared
/// implementation for enrollment/authentication/compare() is what
/// keeps embeddings comparable across the three call sites.
final class FaceAlignment {
    private let outputSize: Int
    private let ciContext = CIContext()

    init(outputSize: Int = 112) {
        self.outputSize = outputSize
    }

    func alignAndNormalize(
        sourceImage: UIImage,
        boxLeft: Int, boxTop: Int, boxWidth: Int, boxHeight: Int,
        leftEyePx: CGPoint, rightEyePx: CGPoint
    ) throws -> [Float] {
        guard boxWidth > 0, boxHeight > 0, let cgImage = sourceImage.cgImage else {
            throw BiometricException(.embeddingGenerationFailed, "Cannot align a face with a non-positive bounding box.")
        }

        let dx = rightEyePx.x - leftEyePx.x
        let dy = rightEyePx.y - leftEyePx.y
        let angle = atan2(dy, dx)
        let eyeCenter = CGPoint(x: (leftEyePx.x + rightEyePx.x) / 2, y: (leftEyePx.y + rightEyePx.y) / 2)

        let ciImage = CIImage(cgImage: cgImage)
        var transform = CGAffineTransform(translationX: eyeCenter.x, y: eyeCenter.y)
        transform = transform.rotated(by: -angle)
        transform = transform.translatedBy(x: -eyeCenter.x, y: -eyeCenter.y)
        let rotated = ciImage.transformed(by: transform)

        let cropRect = CGRect(x: boxLeft, y: boxTop, width: boxWidth, height: boxHeight)
            .intersection(rotated.extent)
        guard !cropRect.isEmpty else {
            throw BiometricException(.embeddingGenerationFailed, "Face crop fell outside frame bounds after rotation correction.")
        }
        let cropped = rotated.cropped(to: cropRect)

        guard let cgCropped = ciContext.createCGImage(cropped, from: cropped.extent) else {
            throw BiometricException(.embeddingGenerationFailed, "Failed to render the aligned face crop.")
        }
        let croppedUIImage = UIImage(cgImage: cgCropped)

        guard let resized = croppedUIImage.resized(to: CGSize(width: outputSize, height: outputSize)) else {
            throw BiometricException(.embeddingGenerationFailed, "Failed to resize the aligned face crop.")
        }

        return try normalizeToTensor(resized)
    }

    private func normalizeToTensor(_ image: UIImage) throws -> [Float] {
        guard let cgImage = image.cgImage else {
            throw BiometricException(.embeddingGenerationFailed, "Resized crop has no backing CGImage.")
        }
        let width = outputSize
        let height = outputSize
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw BiometricException(.embeddingGenerationFailed, "Failed to create a pixel buffer for normalization.")
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var tensor = [Float](repeating: 0, count: width * height * 3)
        var t = 0
        var p = 0
        for _ in 0..<(width * height) {
            let r = Float(pixelData[p]); let g = Float(pixelData[p + 1]); let b = Float(pixelData[p + 2])
            tensor[t] = (r - 127.5) / 127.5; t += 1
            tensor[t] = (g - 127.5) / 127.5; t += 1
            tensor[t] = (b - 127.5) / 127.5; t += 1
            p += 4
        }
        return tensor
    }

    /// Sharpness (Laplacian variance proxy) + mean brightness on the
    /// same crop that would be fed to the embedding model.
    func estimateSharpnessAndBrightness(_ image: UIImage) -> (Double, Double) {
        guard let cgImage = image.cgImage else { return (0, 0) }
        let width = cgImage.width
        let height = cgImage.height
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (0, 0) }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luma = [Double](repeating: 0, count: width * height)
        var sum = 0.0
        var p = 0
        for i in 0..<(width * height) {
            let r = Double(pixelData[p]); let g = Double(pixelData[p + 1]); let b = Double(pixelData[p + 2])
            let y = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            luma[i] = y
            sum += y
            p += 4
        }
        let mean = sum / Double(luma.count)

        var lapSumSq = 0.0
        var count = 0
        if width > 2 && height > 2 {
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let idx = y * width + x
                    let lap = -4 * luma[idx] + luma[idx - 1] + luma[idx + 1] + luma[idx - width] + luma[idx + width]
                    lapSumSq += lap * lap
                    count += 1
                }
            }
        }
        let variance = count > 0 ? (lapSumSq / Double(count)) * 255.0 * 255.0 / 4.0 : 0.0
        return (variance, mean)
    }
}

private extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
