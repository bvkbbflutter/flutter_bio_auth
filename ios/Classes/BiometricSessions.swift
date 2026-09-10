import UIKit

enum StateName: String {
    case idle, initializing, requestingPermission, cameraReady, detectingFace, faceDetected
    case validatingFace, runningLiveness, challengeInProgress, generatingEmbedding, matchingFace
    case checkingAntiSpoof, authenticating, success, failed, timeout, permissionDenied, error
}

protocol SessionRunner: AnyObject {
    func onFrame(_ image: UIImage, _ detection: FaceDetectionResult)
    func fail(_ error: BiometricException)
    func reset()
    func cancel()
}

private func buildQualityAnalyzer(_ minSize: Double, _ maxSize: Double, _ centered: Bool) -> FaceQualityAnalyzer {
    FaceQualityAnalyzer(minimumFaceSize: minSize, maximumFaceSize: maxSize, requireCentered: centered)
}

/// Mirrors Android's EnrollmentSession: detect -> single-face check ->
/// quality gate -> (optional) liveness -> capture N good samples ->
/// mean-aggregate -> L2-normalize -> encrypt -> store. Never builds a
/// template from a single frame.
final class EnrollmentSession: SessionRunner {
    private let userId: String
    private let embeddingEngine: FaceEmbeddingEngine
    private let faceAlignment: FaceAlignment
    private let storage: BiometricTemplateStorage
    private let minimumFaceSize: Double
    private let maximumFaceSize: Double
    private let requireCenteredFace: Bool
    private let requireSingleFace: Bool
    private let requiredSamples: Int
    private let sessionTimeoutMillis: Int64
    private let enableLiveness: Bool
    private let livenessSequence: [LivenessChallenge]
    private let challengeTimeoutMillis: Int64
    private let emitState: (StateName) -> Void
    private let onComplete: ([String: Any?]) -> Void
    private let onError: (BiometricException) -> Void

    private let startedAt = Date().timeIntervalSince1970 * 1000
    private let tracker = FaceTracker()
    private lazy var qualityAnalyzer = buildQualityAnalyzer(minimumFaceSize, maximumFaceSize, requireCenteredFace)
    private lazy var liveness = LivenessEngine(sequence: livenessSequence, challengeTimeoutMillis: challengeTimeoutMillis)
    private var livenessDone: Bool
    private var capturedEmbeddings: [[Float]] = []
    private var finished = false

    init(
        userId: String, embeddingEngine: FaceEmbeddingEngine, faceAlignment: FaceAlignment,
        storage: BiometricTemplateStorage, minimumFaceSize: Double, maximumFaceSize: Double,
        requireCenteredFace: Bool, requireSingleFace: Bool, requiredSamples: Int,
        sessionTimeoutMillis: Int64, enableLiveness: Bool, livenessSequence: [LivenessChallenge],
        challengeTimeoutMillis: Int64, emitState: @escaping (StateName) -> Void,
        onComplete: @escaping ([String: Any?]) -> Void, onError: @escaping (BiometricException) -> Void
    ) {
        self.userId = userId
        self.embeddingEngine = embeddingEngine
        self.faceAlignment = faceAlignment
        self.storage = storage
        self.minimumFaceSize = minimumFaceSize
        self.maximumFaceSize = maximumFaceSize
        self.requireCenteredFace = requireCenteredFace
        self.requireSingleFace = requireSingleFace
        self.requiredSamples = requiredSamples
        self.sessionTimeoutMillis = sessionTimeoutMillis
        self.enableLiveness = enableLiveness
        self.livenessSequence = livenessSequence
        self.challengeTimeoutMillis = challengeTimeoutMillis
        self.emitState = emitState
        self.onComplete = onComplete
        self.onError = onError
        self.livenessDone = !enableLiveness
    }

    func onFrame(_ image: UIImage, _ detection: FaceDetectionResult) {
        if finished { return }
        let now = Date().timeIntervalSince1970 * 1000
        if now - startedAt > Double(sessionTimeoutMillis) {
            return complete(success: false, samples: capturedEmbeddings.count, reason: .sessionTimeout)
        }
        if requireSingleFace && detection.hasMultipleFaces { return }
        if detection.hasNoFace { emitState(.detectingFace); return }
        emitState(.faceDetected)

        let smoothed = tracker.update(detection)

        if !livenessDone {
            emitState(.runningLiveness)
            let outcome = liveness.onFrame(smoothed)
            if outcome?.timedOut == true {
                return complete(success: false, samples: capturedEmbeddings.count, reason: .challengeTimeout)
            }
            if liveness.isFinished {
                let result = liveness.finish()
                if !result.passed {
                    return complete(success: false, samples: capturedEmbeddings.count, reason: .livenessFailed)
                }
                livenessDone = true
            } else {
                return
            }
        }

        emitState(.validatingFace)
        guard let box = detection.boundingBox else { return }
        let (sharpness, brightness) = faceAlignment.estimateSharpnessAndBrightness(image)
        let quality = qualityAnalyzer.analyze(detection: detection, laplacianVariance: sharpness, meanBrightness: brightness)
        guard quality.isAcceptable else { return }

        guard embeddingEngine.isAvailable else {
            return complete(success: false, samples: capturedEmbeddings.count, reason: .modelUnavailable)
        }
        guard detection.landmarks.count >= 2 else { return }

        do {
            emitState(.generatingEmbedding)
            let leftEyePx = CGPoint(x: detection.landmarks[0].x * Double(image.size.width), y: detection.landmarks[0].y * Double(image.size.height))
            let rightEyePx = CGPoint(x: detection.landmarks[1].x * Double(image.size.width), y: detection.landmarks[1].y * Double(image.size.height))
            let tensor = try faceAlignment.alignAndNormalize(
                sourceImage: image,
                boxLeft: Int(box.left * Double(image.size.width)), boxTop: Int(box.top * Double(image.size.height)),
                boxWidth: Int(box.width * Double(image.size.width)), boxHeight: Int(box.height * Double(image.size.height)),
                leftEyePx: leftEyePx, rightEyePx: rightEyePx
            )
            let embedding = try embeddingEngine.generateEmbedding(alignedTensor: tensor)
            capturedEmbeddings.append(embedding)
        } catch {
            return // skip this frame; only the timeout path aborts the session
        }

        if capturedEmbeddings.count >= requiredSamples {
            let aggregated = aggregate(capturedEmbeddings)
            let template = FaceTemplateNative(
                version: FaceTemplateNative.currentTemplateVersion, modelVersion: embeddingEngine.modelVersion,
                embeddingDimension: embeddingEngine.embeddingDimension, embedding: aggregated,
                createdAtEpochMillis: Int64(Date().timeIntervalSince1970 * 1000)
            )
            do {
                try storage.save(userId: userId, template: template)
            } catch {
                return complete(success: false, samples: capturedEmbeddings.count, reason: .unknown)
            }
            complete(success: true, samples: capturedEmbeddings.count, reason: nil)
        }
    }

    private func aggregate(_ embeddings: [[Float]]) -> [Float] {
        let dim = embeddings[0].count
        var mean = [Float](repeating: 0, count: dim)
        for e in embeddings { for i in 0..<dim { mean[i] += e[i] / Float(embeddings.count) } }
        let normSq = mean.reduce(0.0) { $0 + Double($1) * Double($1) }
        let norm = sqrt(normSq)
        guard norm != 0 else { return mean }
        return mean.map { Float(Double($0) / norm) }
    }

    private func complete(success: Bool, samples: Int, reason: FaceAuthenticationFailureReason?) {
        finished = true
        emitState(success ? .success : .failed)
        onComplete([
            "success": success, "userId": userId, "samplesUsed": samples,
            "durationMs": Int(Date().timeIntervalSince1970 * 1000 - startedAt), "failureReason": reason?.rawValue,
        ])
    }

    func fail(_ error: BiometricException) {
        if finished { return }
        finished = true
        emitState(.error)
        onError(error)
    }

    func reset() {
        finished = false
        capturedEmbeddings.removeAll()
        tracker.reset()
        liveness.reset()
        livenessDone = !enableLiveness
    }

    func cancel() { finished = true }
}

/// Mirrors Android's AuthenticationSession: detect -> quality ->
/// (optional) liveness -> (optional) anti-spoof -> align -> embed ->
/// compare -> AuthenticationEngine decision.
final class AuthenticationSession: SessionRunner {
    private let userId: String
    private let enrolledTemplate: FaceTemplateNative
    private let embeddingEngine: FaceEmbeddingEngine
    private let antiSpoofEngine: AntiSpoofEngine
    private let faceAlignment: FaceAlignment
    private let faceMatcher: FaceMatcher
    private let authenticationEngine: AuthenticationEngine
    private let minimumFaceSize: Double
    private let maximumFaceSize: Double
    private let requireCenteredFace: Bool
    private let requireSingleFace: Bool
    private let sessionTimeoutMillis: Int64
    private let enableLiveness: Bool
    private let livenessSequence: [LivenessChallenge]
    private let challengeTimeoutMillis: Int64
    private let emitState: (StateName) -> Void
    private let onComplete: ([String: Any?]) -> Void
    private let onError: (BiometricException) -> Void

    private let startedAt = Date().timeIntervalSince1970 * 1000
    private let tracker = FaceTracker()
    private lazy var qualityAnalyzer = buildQualityAnalyzer(minimumFaceSize, maximumFaceSize, requireCenteredFace)
    private lazy var liveness = LivenessEngine(sequence: livenessSequence, challengeTimeoutMillis: challengeTimeoutMillis)
    private var livenessDone: Bool
    private var livenessScore: Double
    private var livenessPassed: Bool
    private var finished = false

    init(
        userId: String, enrolledTemplate: FaceTemplateNative, embeddingEngine: FaceEmbeddingEngine,
        antiSpoofEngine: AntiSpoofEngine, faceAlignment: FaceAlignment, faceMatcher: FaceMatcher,
        authenticationEngine: AuthenticationEngine, minimumFaceSize: Double, maximumFaceSize: Double,
        requireCenteredFace: Bool, requireSingleFace: Bool, sessionTimeoutMillis: Int64, enableLiveness: Bool,
        livenessSequence: [LivenessChallenge], challengeTimeoutMillis: Int64,
        emitState: @escaping (StateName) -> Void, onComplete: @escaping ([String: Any?]) -> Void,
        onError: @escaping (BiometricException) -> Void
    ) {
        self.userId = userId
        self.enrolledTemplate = enrolledTemplate
        self.embeddingEngine = embeddingEngine
        self.antiSpoofEngine = antiSpoofEngine
        self.faceAlignment = faceAlignment
        self.faceMatcher = faceMatcher
        self.authenticationEngine = authenticationEngine
        self.minimumFaceSize = minimumFaceSize
        self.maximumFaceSize = maximumFaceSize
        self.requireCenteredFace = requireCenteredFace
        self.requireSingleFace = requireSingleFace
        self.sessionTimeoutMillis = sessionTimeoutMillis
        self.enableLiveness = enableLiveness
        self.livenessSequence = livenessSequence
        self.challengeTimeoutMillis = challengeTimeoutMillis
        self.emitState = emitState
        self.onComplete = onComplete
        self.onError = onError
        self.livenessDone = !enableLiveness
        self.livenessScore = enableLiveness ? 0.0 : 1.0
        self.livenessPassed = !enableLiveness
    }

    func onFrame(_ image: UIImage, _ detection: FaceDetectionResult) {
        if finished { return }
        let now = Date().timeIntervalSince1970 * 1000
        if now - startedAt > Double(sessionTimeoutMillis) {
            return complete(makeFailure(.sessionTimeout))
        }
        if requireSingleFace && detection.hasMultipleFaces { return }
        if detection.hasNoFace { emitState(.detectingFace); return }
        emitState(.faceDetected)

        let smoothed = tracker.update(detection)

        if !livenessDone {
            emitState(.runningLiveness)
            let outcome = liveness.onFrame(smoothed)
            if outcome?.timedOut == true { return complete(makeFailure(.challengeTimeout)) }
            if liveness.isFinished {
                let result = liveness.finish()
                livenessPassed = result.passed
                livenessScore = result.overallScore
                livenessDone = true
                if !result.passed { return complete(makeFailure(.livenessFailed)) }
            } else {
                return
            }
        }

        emitState(.validatingFace)
        guard let box = detection.boundingBox else { return }
        let (sharpness, brightness) = faceAlignment.estimateSharpnessAndBrightness(image)
        let quality = qualityAnalyzer.analyze(detection: detection, laplacianVariance: sharpness, meanBrightness: brightness)
        guard quality.isAcceptable else { return }
        guard embeddingEngine.isAvailable else { return complete(makeFailure(.modelUnavailable)) }
        guard detection.landmarks.count >= 2 else { return }

        do {
            emitState(.generatingEmbedding)
            let leftEyePx = CGPoint(x: detection.landmarks[0].x * Double(image.size.width), y: detection.landmarks[0].y * Double(image.size.height))
            let rightEyePx = CGPoint(x: detection.landmarks[1].x * Double(image.size.width), y: detection.landmarks[1].y * Double(image.size.height))
            let tensor = try faceAlignment.alignAndNormalize(
                sourceImage: image,
                boxLeft: Int(box.left * Double(image.size.width)), boxTop: Int(box.top * Double(image.size.height)),
                boxWidth: Int(box.width * Double(image.size.width)), boxHeight: Int(box.height * Double(image.size.height)),
                leftEyePx: leftEyePx, rightEyePx: rightEyePx
            )

            emitState(.checkingAntiSpoof)
            let antiSpoofResult = antiSpoofEngine.analyze(alignedTensor: tensor)

            emitState(.generatingEmbedding)
            let liveEmbedding = try embeddingEngine.generateEmbedding(alignedTensor: tensor)

            emitState(.matchingFace)
            let similarity = try faceMatcher.cosineSimilarity(liveEmbedding, enrolledTemplate.embedding)

            emitState(.authenticating)
            let decision = authenticationEngine.decide(similarity: similarity, livenessPassed: livenessPassed, livenessScore: livenessScore, antiSpoofResult: antiSpoofResult)

            complete([
                "authenticated": decision.authenticated, "userId": userId, "similarity": decision.similarity,
                "livenessScore": decision.livenessScore, "antiSpoofScore": decision.antiSpoofScore,
                "durationMs": Int(Date().timeIntervalSince1970 * 1000 - startedAt), "failureReason": decision.failureReason?.rawValue,
            ])
        } catch {
            return complete(makeFailure(.unknown))
        }
    }

    private func makeFailure(_ reason: FaceAuthenticationFailureReason) -> [String: Any?] {
        [
            "authenticated": false, "userId": userId, "similarity": 0.0, "livenessScore": livenessScore,
            "antiSpoofScore": 0.0, "durationMs": Int(Date().timeIntervalSince1970 * 1000 - startedAt),
            "failureReason": reason.rawValue,
        ]
    }

    private func complete(_ resultMap: [String: Any?]) {
        finished = true
        emitState((resultMap["authenticated"] as? Bool == true) ? .success : .failed)
        onComplete(resultMap)
    }

    func fail(_ error: BiometricException) {
        if finished { return }
        finished = true
        emitState(.error)
        onError(error)
    }

    func reset() {
        finished = false
        tracker.reset()
        liveness.reset()
        livenessDone = !enableLiveness
        livenessPassed = !enableLiveness
        livenessScore = enableLiveness ? 0.0 : 1.0
    }

    func cancel() { finished = true }
}

/// Standalone active liveness verification session. Evaluates the user against
/// sequential liveness challenges without requiring an embedding model.
final class LivenessSession: SessionRunner {
    private let minimumFaceSize: Double
    private let maximumFaceSize: Double
    private let requireCenteredFace: Bool
    private let requireSingleFace: Bool
    private let sessionTimeoutMillis: Int64
    private let livenessSequence: [LivenessChallenge]
    private let challengeTimeoutMillis: Int64
    private let emitState: (StateName) -> Void
    private let emitChallengeProgress: ([String: Any]) -> Void
    private let onComplete: ([String: Any?]) -> Void
    private let onError: (BiometricException) -> Void

    private let startedAt = Date().timeIntervalSince1970 * 1000
    private let tracker = FaceTracker()
    private lazy var qualityAnalyzer = buildQualityAnalyzer(minimumFaceSize, maximumFaceSize, requireCenteredFace)
    private lazy var liveness = LivenessEngine(sequence: livenessSequence, challengeTimeoutMillis: challengeTimeoutMillis)
    private var finished = false

    init(
        minimumFaceSize: Double,
        maximumFaceSize: Double,
        requireCenteredFace: Bool,
        requireSingleFace: Bool,
        sessionTimeoutMillis: Int64,
        livenessSequence: [LivenessChallenge],
        challengeTimeoutMillis: Int64,
        emitState: @escaping (StateName) -> Void,
        emitChallengeProgress: @escaping ([String: Any]) -> Void,
        onComplete: @escaping ([String: Any?]) -> Void,
        onError: @escaping (BiometricException) -> Void
    ) {
        self.minimumFaceSize = minimumFaceSize
        self.maximumFaceSize = maximumFaceSize
        self.requireCenteredFace = requireCenteredFace
        self.requireSingleFace = requireSingleFace
        self.sessionTimeoutMillis = sessionTimeoutMillis
        self.livenessSequence = livenessSequence
        self.challengeTimeoutMillis = challengeTimeoutMillis
        self.emitState = emitState
        self.emitChallengeProgress = emitChallengeProgress
        self.onComplete = onComplete
        self.onError = onError
    }

    func onFrame(_ image: UIImage, _ detection: FaceDetectionResult) {
        if finished { return }
        let now = Date().timeIntervalSince1970 * 1000
        if now - startedAt > Double(sessionTimeoutMillis) {
            return complete(success: false, failureReason: "sessionTimeout")
        }
        if requireSingleFace && detection.hasMultipleFaces {
            return
        }
        if detection.hasNoFace {
            emitState(.detectingFace)
            return
        }
        emitState(.faceDetected)

        let smoothed = tracker.update(detection)
        emitState(.runningLiveness)

        guard let outcome = liveness.onFrame(smoothed) else { return }

        emitChallengeProgress([
            "challenge": outcome.challenge?.rawValue ?? "",
            "confidence": outcome.confidence,
            "completed": outcome.completed,
            "timedOut": outcome.timedOut,
            "progress": min(1.0, max(0.0, outcome.progress)),
        ])

        if outcome.timedOut {
            return complete(success: false, failureReason: "challengeTimeout")
        }

        if liveness.isFinished {
            let result = liveness.finish()
            complete(
                success: result.passed,
                failureReason: result.passed ? nil : "livenessFailed"
            )
        }
    }

    private func complete(success: Bool, failureReason: String?) {
        if finished { return }
        finished = true
        emitState(success ? .success : .failed)
        let finishResult = liveness.finish()
        onComplete([
            "success": success,
            "overallScore": success ? finishResult.overallScore : 0.0,
            "durationMs": Int(Date().timeIntervalSince1970 * 1000 - startedAt),
            "completedChallenges": finishResult.completedChallenges.map { $0.rawValue },
            "failureReason": failureReason,
        ])
    }

    func fail(_ error: BiometricException) {
        if finished { return }
        finished = true
        emitState(.error)
        onError(error)
    }

    func reset() {
        finished = false
        tracker.reset()
        liveness.reset()
    }

    func cancel() {
        finished = true
    }
}

