import AVFoundation
import Vision
import UIKit

/// Wraps Apple's on-device Vision face-landmarks request. Vision ships
/// as part of iOS itself -- this class bundles zero model bytes.
/// Produces bounding box, 2D landmarks, and roll/yaw from
/// `VNFaceObservation`. iOS's Vision API does not expose a pitch or
/// smiling/eye-open *probability* the way ML Kit does, so
/// [FaceQualityAnalyzer]/[BlinkDetector]/[SmileDetector] on this
/// platform derive their signals from landmark geometry instead (eye
/// aspect ratio for blink, mouth aspect ratio for smile) -- see the
/// `deriveEyeOpenProbability`/`deriveSmileProbability` helpers below.
final class FaceAnalyzer {

    private let sequenceHandler = VNSequenceRequestHandler()
    private var nextTrackingId = 0
    private var trackingIdsByRect: [String: Int] = [:]

    func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (FaceDetectionResult) -> Void
    ) {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            guard error == nil, let results = request.results as? [VNFaceObservation] else {
                completion(FaceDetectionResult.noFace())
                return
            }
            completion(self.toDetectionResult(results))
        }
        request.revision = VNDetectFaceLandmarksRequestRevision3

        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)
        } catch {
            completion(FaceDetectionResult.noFace())
        }
    }

    /// Still-image counterpart to `analyze(pixelBuffer:...)`, used by
    /// `compare()` where there is no live capture buffer -- only a
    /// `UIImage` decoded from bytes passed across the platform
    /// channel. Uses a fresh `VNImageRequestHandler` per call (Vision's
    /// sequence handler is for temporal frame sequences, not one-off
    /// stills) but the same `VNDetectFaceLandmarksRequest`
    /// configuration as the live path.
    func analyze(image: UIImage, completion: @escaping (FaceDetectionResult) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(FaceDetectionResult.noFace())
            return
        }
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            guard error == nil, let results = request.results as? [VNFaceObservation] else {
                completion(FaceDetectionResult.noFace())
                return
            }
            completion(self.toDetectionResult(results))
        }
        request.revision = VNDetectFaceLandmarksRequestRevision3

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion(FaceDetectionResult.noFace())
        }
    }

    private func toDetectionResult(_ faces: [VNFaceObservation]) -> FaceDetectionResult {
        guard faces.count == 1, let face = faces.first else {
            return FaceDetectionResult(
                faceCount: faces.count, trackingId: nil, boundingBox: nil, landmarks: [],
                yawDegrees: nil, pitchDegrees: nil, rollDegrees: nil,
                leftEyeOpenProbability: nil, rightEyeOpenProbability: nil, smilingProbability: nil
            )
        }

        // Vision's boundingBox is normalized with origin at bottom-left;
        // convert to top-left origin to match the Dart-side contract
        // (and Android's convention).
        let box = face.boundingBox
        let normalizedBox = FaceBoundingBox(
            left: Double(box.minX), top: Double(1 - box.maxY),
            width: Double(box.width), height: Double(box.height)
        )

        var landmarkPoints: [FaceLandmarkPoint] = []
        var leftEAR: Double?
        var rightEAR: Double?
        var mouthAspectRatio: Double?

        if let landmarks = face.landmarks {
            if let leftEye = landmarks.leftEye { leftEAR = eyeAspectRatio(leftEye) }
            if let rightEye = landmarks.rightEye { rightEAR = eyeAspectRatio(rightEye) }
            if let outerLips = landmarks.outerLips { mouthAspectRatio = mouthOpenRatio(outerLips) }

            if let leftPupil = landmarks.leftPupil?.normalizedPoints.first {
                landmarkPoints.append(denormalize(leftPupil, in: box))
            }
            if let rightPupil = landmarks.rightPupil?.normalizedPoints.first {
                landmarkPoints.append(denormalize(rightPupil, in: box))
            }
        }

        let roll = face.roll?.doubleValue.map { $0 * 180.0 / .pi }
        let yaw = face.yaw?.doubleValue.map { $0 * 180.0 / .pi }

        return FaceDetectionResult(
            faceCount: 1,
            trackingId: stableTrackingId(for: box),
            boundingBox: normalizedBox,
            landmarks: landmarkPoints,
            yawDegrees: yaw,
            // Vision (as of the revisions available here) does not
            // expose head pitch directly; leave nil so lookUp/lookDown
            // challenges fail closed (never falsely "pass") rather than
            // deriving an unreliable proxy. See README limitations.
            pitchDegrees: nil,
            rollDegrees: roll,
            leftEyeOpenProbability: leftEAR.map { earToOpenProbability($0) },
            rightEyeOpenProbability: rightEAR.map { earToOpenProbability($0) },
            smilingProbability: mouthAspectRatio.map { marToSmileProbability($0) }
        )
    }

    private func denormalize(_ point: CGPoint, in box: CGRect) -> FaceLandmarkPoint {
        let x = box.minX + point.x * box.width
        let y = 1 - (box.minY + point.y * box.height)
        return FaceLandmarkPoint(x: Double(x), y: Double(y))
    }

    private func eyeAspectRatio(_ region: VNFaceLandmarkRegion2D) -> Double? {
        let pts = region.normalizedPoints
        guard pts.count >= 6 else { return nil }
        func dist(_ a: CGPoint, _ b: CGPoint) -> Double {
            Double(sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2)))
        }
        let vertical1 = dist(pts[1], pts[5])
        let vertical2 = dist(pts[2], pts[4])
        let horizontal = dist(pts[0], pts[3])
        guard horizontal > 0 else { return nil }
        return (vertical1 + vertical2) / (2.0 * horizontal)
    }

    private func mouthOpenRatio(_ region: VNFaceLandmarkRegion2D) -> Double? {
        let pts = region.normalizedPoints
        guard pts.count >= 8 else { return nil }
        func dist(_ a: CGPoint, _ b: CGPoint) -> Double {
            Double(sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2)))
        }
        let width = dist(pts[0], pts[6])
        let height = dist(pts[3], pts[9 % pts.count])
        guard width > 0 else { return nil }
        return height / width
    }

    /// Empirically-tuned mapping; typical open-eye EAR is ~0.25-0.35,
    /// closed is <0.15. Not a substitute for a trained classifier, but
    /// sufficient to drive a blink state machine that requires a full
    /// open->closed->open transition (see BlinkDetector.swift).
    private func earToOpenProbability(_ ear: Double) -> Double {
        let normalized = (ear - 0.12) / (0.30 - 0.12)
        return normalized.clamped(to: 0.0...1.0)
    }

    private func marToSmileProbability(_ mar: Double) -> Double {
        let normalized = (mar - 0.15) / (0.45 - 0.15)
        return normalized.clamped(to: 0.0...1.0)
    }

    /// Vision doesn't provide a persistent tracking ID the way ML Kit
    /// does; approximate continuity by rounding the bounding box to a
    /// coarse grid so small frame-to-frame jitter still maps to the
    /// "same" id, while a genuinely different face location resets it.
    private func stableTrackingId(for box: CGRect) -> Int {
        let key = "\(Int(box.midX * 20))_\(Int(box.midY * 20))"
        if let existing = trackingIdsByRect[key] { return existing }
        nextTrackingId += 1
        trackingIdsByRect = [key: nextTrackingId] // keep the map small
        return nextTrackingId
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension CGImagePropertyOrientation {
    /// Maps UIImage's orientation enum to Vision's, so a still image
    /// decoded from arbitrary JPEG/PNG bytes (which may carry EXIF
    /// rotation) is analyzed right-side-up.
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
