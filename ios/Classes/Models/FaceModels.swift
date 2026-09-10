import Foundation

/// Mirrors lib/src/liveness_challenge.dart LivenessChallenge.
enum LivenessChallenge: String, CaseIterable {
    case blink, smile, turnLeft, turnRight, lookUp, lookDown, moveCloser, moveAway
}

/// Mirrors lib/src/biometric_failure_reason.dart.
enum FaceAuthenticationFailureReason: String {
    case faceNotDetected, multipleFacesDetected, poorFaceQuality, livenessFailed
    case challengeTimeout, antiSpoofFailed, faceMismatch, templateNotFound
    case templateDecryptionFailed, modelUnavailable, modelVersionMismatch
    case sessionTimeout, cameraPermissionDenied, cameraUnavailable, cancelled, unknown
}

/// Mirrors lib/src/biometric_error.dart FaceBiometricErrorCode. Used
/// as the FlutterError `code` so Dart can map it back losslessly.
enum FaceBiometricErrorCode: String {
    case cameraPermissionDenied, cameraUnavailable, faceNotDetected
    case multipleFacesDetected, faceTooSmall, faceTooLarge, faceNotCentered
    case poorFaceQuality, modelUnavailable, modelInitializationFailed
    case embeddingGenerationFailed, templateNotFound, templateDecryptionFailed
    case livenessFailed, antiSpoofFailed, faceMismatch, timeout, storageError
    case encryptionError, platformError, invalidConfiguration, notInitialized
}

/// The single exception type every native engine throws. The plugin's
/// method dispatcher converts these into `FlutterError`s and never lets
/// a raw NSError with sensitive details escape to Dart.
struct BiometricException: Error {
    let errorCode: FaceBiometricErrorCode
    let message: String
    let underlying: Error?

    init(_ errorCode: FaceBiometricErrorCode, _ message: String, underlying: Error? = nil) {
        self.errorCode = errorCode
        self.message = message
        self.underlying = underlying
    }
}

struct FaceBoundingBox {
    let left: Double
    let top: Double
    let width: Double
    let height: Double

    var toMap: [String: Any] { ["left": left, "top": top, "width": width, "height": height] }
}

struct FaceLandmarkPoint {
    let x: Double
    let y: Double
    var toMap: [String: Any] { ["x": x, "y": y] }
}

/// One frame's worth of native face-detector output, produced by
/// Vision (`VNDetectFaceLandmarksRequest`) -- built into iOS, no
/// bundled model required.
struct FaceDetectionResult {
    let faceCount: Int
    let trackingId: Int?
    let boundingBox: FaceBoundingBox?
    let landmarks: [FaceLandmarkPoint]
    let yawDegrees: Double?
    let pitchDegrees: Double?
    let rollDegrees: Double?
    let leftEyeOpenProbability: Double?
    let rightEyeOpenProbability: Double?
    let smilingProbability: Double?

    var hasNoFace: Bool { faceCount == 0 }
    var hasMultipleFaces: Bool { faceCount > 1 }

    static func noFace() -> FaceDetectionResult {
        FaceDetectionResult(
            faceCount: 0, trackingId: nil, boundingBox: nil, landmarks: [],
            yawDegrees: nil, pitchDegrees: nil, rollDegrees: nil,
            leftEyeOpenProbability: nil, rightEyeOpenProbability: nil, smilingProbability: nil
        )
    }

    func toMap() -> [String: Any?] {
        [
            "faceCount": faceCount, "trackingId": trackingId,
            "boundingBox": boundingBox?.toMap,
            "landmarks": landmarks.map { $0.toMap },
            "yawDegrees": yawDegrees, "pitchDegrees": pitchDegrees, "rollDegrees": rollDegrees,
            "leftEyeOpenProbability": leftEyeOpenProbability,
            "rightEyeOpenProbability": rightEyeOpenProbability,
            "smilingProbability": smilingProbability,
        ]
    }
}

struct FaceQualityResult {
    let overallScore: Double
    let isBlurry: Bool
    let isTooSmall: Bool
    let isTooLarge: Bool
    let isCentered: Bool
    let isFrontal: Bool
    let brightness: Double

    var isAcceptable: Bool { !isBlurry && !isTooSmall && !isTooLarge && isCentered && isFrontal }
}

enum AntiSpoofReason: String {
    case live, photo, screenReplay, videoReplay, suspiciousTexture, suspiciousMotion
    case lowConfidence, modelUnavailable, unknown
}

struct AntiSpoofResult {
    let isLive: Bool
    let confidence: Double
    let reason: AntiSpoofReason

    /// Absence of a configured model must never read as a pass.
    static let unavailable = AntiSpoofResult(isLive: false, confidence: 0.0, reason: .modelUnavailable)
}

struct LivenessResult {
    let passed: Bool
    let overallScore: Double
    let completedChallenges: [LivenessChallenge]
    let failedChallenge: LivenessChallenge?
}

struct FaceTemplateNative {
    static let currentTemplateVersion = 1

    let version: Int
    let modelVersion: String
    let embeddingDimension: Int
    let embedding: [Float]
    let createdAtEpochMillis: Int64
}
