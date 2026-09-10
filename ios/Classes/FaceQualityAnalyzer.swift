import Foundation

/// Mirrors FaceQualityAnalyzer.kt. Entirely deterministic (geometry +
/// a caller-supplied sharpness/brightness estimate) -- no ML model
/// involved, so this always works with zero bundled models. Note:
/// `isFrontal` on iOS only checks yaw (Vision doesn't expose pitch;
/// see FaceAnalyzer.swift), which is a slightly weaker frontal check
/// than Android's yaw+pitch version.
final class FaceQualityAnalyzer {
    private let minimumFaceSize: Double
    private let maximumFaceSize: Double
    private let requireCentered: Bool
    private let maxFrontalYawDegrees: Double
    private let centeringTolerance: Double
    private let minAcceptableBrightness: Double
    private let maxAcceptableBrightness: Double
    private let blurVarianceThreshold: Double

    init(
        minimumFaceSize: Double, maximumFaceSize: Double, requireCentered: Bool,
        maxFrontalYawDegrees: Double = 15.0, centeringTolerance: Double = 0.18,
        minAcceptableBrightness: Double = 0.18, maxAcceptableBrightness: Double = 0.92,
        blurVarianceThreshold: Double = 35.0
    ) {
        self.minimumFaceSize = minimumFaceSize
        self.maximumFaceSize = maximumFaceSize
        self.requireCentered = requireCentered
        self.maxFrontalYawDegrees = maxFrontalYawDegrees
        self.centeringTolerance = centeringTolerance
        self.minAcceptableBrightness = minAcceptableBrightness
        self.maxAcceptableBrightness = maxAcceptableBrightness
        self.blurVarianceThreshold = blurVarianceThreshold
    }

    func analyze(
        detection: FaceDetectionResult, laplacianVariance: Double, meanBrightness: Double
    ) -> FaceQualityResult {
        let box = detection.boundingBox
        let faceHeight = box?.height ?? 0.0

        let isTooSmall = faceHeight < minimumFaceSize
        let isTooLarge = faceHeight > maximumFaceSize

        let isCentered: Bool
        if !requireCentered || box == nil {
            isCentered = true
        } else {
            let centerX = box!.left + box!.width / 2.0
            let centerY = box!.top + box!.height / 2.0
            isCentered = abs(centerX - 0.5) <= centeringTolerance && abs(centerY - 0.5) <= centeringTolerance
        }

        let isFrontal = detection.yawDegrees.map { abs($0) <= maxFrontalYawDegrees } ?? false
        let isBlurry = laplacianVariance < blurVarianceThreshold
        let brightnessOk = meanBrightness >= minAcceptableBrightness && meanBrightness <= maxAcceptableBrightness

        let sizeScore = (isTooSmall || isTooLarge) ? 0.0 : 1.0
        let centerScore = isCentered ? 1.0 : 0.3
        let frontalScore = isFrontal ? 1.0 : 0.3
        let blurScore = min(1.0, max(0.0, laplacianVariance / (blurVarianceThreshold * 3)))
        let brightnessScore = brightnessOk ? 1.0 : 0.4

        let overall = (sizeScore * 0.30) + (centerScore * 0.15) + (frontalScore * 0.20)
            + (blurScore * 0.20) + (brightnessScore * 0.15)

        return FaceQualityResult(
            overallScore: min(1.0, max(0.0, overall)), isBlurry: isBlurry, isTooSmall: isTooSmall,
            isTooLarge: isTooLarge, isCentered: isCentered, isFrontal: isFrontal, brightness: meanBrightness
        )
    }
}
