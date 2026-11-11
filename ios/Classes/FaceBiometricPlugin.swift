import Flutter
import UIKit
import LocalAuthentication

public class FaceBiometricPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    // Configuration.
    private var recognitionThreshold = 0.68
    private var livenessThreshold = 0.80
    private var antiSpoofThreshold = 0.80
    private var enableLiveness = true
    private var enableAntiSpoofing = true
    private var challengePool: [LivenessChallenge] = [.blink]
    private var randomizeChallenges = true
    private var challengeTimeoutMillis: Int64 = 8000
    private var sessionTimeoutMillis: Int64 = 45000
    private var minimumFaceSize = 0.15
    private var maximumFaceSize = 0.85
    private var requireSingleFace = true
    private var requireCenteredFace = true
    private var mirrorPreview = true
    private var embeddingDimension = 192
    private let modelVersion = "face-model-1"

    private var cryptoManager: CryptoManager?
    private var storage: BiometricTemplateStorage?
    private var embeddingEngine: FaceEmbeddingEngine?
    private var antiSpoofEngine: AntiSpoofEngine?
    private var cameraManager: CameraManager?
    private weak var activeView: FaceBiometricView?
    private let faceAlignment = FaceAlignment()
    private let faceMatcher = FaceMatcher()
    private var activeSession: SessionRunner?
    private var registrar: FlutterPluginRegistrar?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FaceBiometricPlugin()
        instance.registrar = registrar

        let methodChannel = FlutterMethodChannel(name: "flutter_bio_auth/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(name: "flutter_bio_auth/state_events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)

        let viewFactory = FaceBiometricViewFactory(
            cameraManagerProvider: { instance.cameraManager },
            mirrorProvider: { instance.mirrorPreview },
            onViewCreated: { [weak instance] view in
                instance?.activeView = view
                if let manager = instance?.cameraManager {
                    view.attach(cameraManager: manager)
                }
            },
            onViewDisposed: { [weak instance] in
                instance?.activeView = nil
            }
        )
        registrar.register(viewFactory, withId: "flutter_bio_auth/camera_preview")
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func emit(_ state: StateName) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(state.rawValue)
        }
    }

    private func emitProgress(_ map: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(map)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            switch call.method {
            case "initialize": try handleInitialize(call, result)
            case "enroll": try handleEnroll(call, result)
            case "authenticate": try handleAuthenticate(call, result)
            case "verifyLiveness": try handleVerifyLiveness(call, result)
            case "compare": try handleCompare(call, result)
            case "isEnrolled":
                let userId = (call.arguments as? [String: Any])?["userId"] as? String ?? ""
                result(storageOrThrow().exists(userId: userId))
            case "deleteEnrollment":
                let userId = (call.arguments as? [String: Any])?["userId"] as? String ?? ""
                storageOrThrow().delete(userId: userId)
                result(nil)
            case "getEnrolledUsers": result(storageOrThrow().getUsers())
            case "clearAllEnrollments": storageOrThrow().clear(); result(nil)
            case "authenticateWithDeviceBiometrics": handleDeviceBiometrics(call, result)
            case "retry": activeSession?.reset(); result(nil)
            case "dispose": handleDispose(); result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        } catch let error as BiometricException {
            result(FlutterError(code: error.errorCode.rawValue, message: error.message, details: nil))
        } catch {
            result(FlutterError(code: FaceBiometricErrorCode.platformError.rawValue, message: error.localizedDescription, details: nil))
        }
    }

    private func storageOrThrow() -> BiometricTemplateStorage {
        guard let storage = storage else {
            // Should not normally happen: Dart's FaceBiometric checks
            // _initialized before any call reaches here.
            fatalError("flutter_bio_auth: storage accessed before initialize()")
        }
        return storage
    }

    private func handleInitialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
        guard let args = call.arguments as? [String: Any] else {
            throw BiometricException(.invalidConfiguration, "initialize() requires a configuration map.")
        }
        recognitionThreshold = args["recognitionThreshold"] as? Double ?? recognitionThreshold
        livenessThreshold = args["livenessThreshold"] as? Double ?? livenessThreshold
        antiSpoofThreshold = args["antiSpoofThreshold"] as? Double ?? antiSpoofThreshold
        enableLiveness = args["enableLiveness"] as? Bool ?? enableLiveness
        enableAntiSpoofing = args["enableAntiSpoofing"] as? Bool ?? enableAntiSpoofing
        if let names = args["challenges"] as? [String] {
            challengePool = names.compactMap { LivenessChallenge(rawValue: $0) }
        }
        randomizeChallenges = args["randomizeChallenges"] as? Bool ?? randomizeChallenges
        challengeTimeoutMillis = (args["challengeTimeoutMs"] as? NSNumber)?.int64Value ?? challengeTimeoutMillis
        sessionTimeoutMillis = (args["sessionTimeoutMs"] as? NSNumber)?.int64Value ?? sessionTimeoutMillis
        minimumFaceSize = args["minimumFaceSize"] as? Double ?? minimumFaceSize
        maximumFaceSize = args["maximumFaceSize"] as? Double ?? maximumFaceSize
        requireSingleFace = args["requireSingleFace"] as? Bool ?? requireSingleFace
        requireCenteredFace = args["requireCenteredFace"] as? Bool ?? requireCenteredFace
        mirrorPreview = args["mirrorPreview"] as? Bool ?? mirrorPreview
        embeddingDimension = (args["embeddingDimension"] as? NSNumber)?.intValue ?? embeddingDimension

        let embeddingAssetPath = args["embeddingModelAssetPath"] as? String
        let antiSpoofAssetPath = args["antiSpoofModelAssetPath"] as? String

        let crypto = CryptoManager()
        cryptoManager = crypto
        storage = UserDefaultsTemplateStorage(crypto: crypto)

        embeddingEngine = makeEmbeddingEngine(assetPath: embeddingAssetPath)
        antiSpoofEngine = makeAntiSpoofEngine(assetPath: antiSpoofAssetPath)

        result(nil)
    }

    /// Resolves a Flutter asset path (declared by the *consuming app*)
    /// to a compiled model URL. NOTE: CoreML requires a *compiled*
    /// `.mlmodelc` bundle rather than a raw `.tflite`/`.mlmodel` file;
    /// production integration should either bundle a pre-compiled
    /// `.mlmodelc` as the asset, or compile it on first launch with
    /// `MLModel.compileModel(at:)`. This resolves the asset key via the
    /// registrar and leaves the engine `unavailable` (fail-closed,
    /// never fake) if the lookup or load fails.
    private func makeEmbeddingEngine(assetPath: String?) -> FaceEmbeddingEngine {
        guard let assetPath = assetPath, let registrar = registrar else {
            return UnavailableFaceEmbeddingEngine(modelVersion: modelVersion, embeddingDimension: embeddingDimension)
        }
        let key = registrar.lookupKey(forAsset: assetPath)
        guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
            return UnavailableFaceEmbeddingEngine(modelVersion: modelVersion, embeddingDimension: embeddingDimension)
        }
        return CoreMLFaceEmbeddingEngine(compiledModelURL: URL(fileURLWithPath: path), modelVersion: modelVersion, embeddingDimension: embeddingDimension)
    }

    private func makeAntiSpoofEngine(assetPath: String?) -> AntiSpoofEngine {
        guard let assetPath = assetPath, let registrar = registrar else { return UnavailableAntiSpoofEngine() }
        let key = registrar.lookupKey(forAsset: assetPath)
        guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return UnavailableAntiSpoofEngine() }
        return CoreMLAntiSpoofEngine(compiledModelURL: URL(fileURLWithPath: path))
    }

    private func handleDispose() {
        activeSession?.cancel()
        activeSession = nil
        cameraManager?.dispose()
        cameraManager = nil
    }

    private func handleEnroll(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
        guard let userId = (call.arguments as? [String: Any])?["userId"] as? String else {
            throw BiometricException(.invalidConfiguration, "enroll() requires userId.")
        }
        let session = EnrollmentSession(
            userId: userId, embeddingEngine: embeddingEngine!, faceAlignment: faceAlignment,
            storage: storageOrThrow(), minimumFaceSize: minimumFaceSize, maximumFaceSize: maximumFaceSize,
            requireCenteredFace: requireCenteredFace, requireSingleFace: requireSingleFace, requiredSamples: 5,
            sessionTimeoutMillis: sessionTimeoutMillis, enableLiveness: enableLiveness,
            livenessSequence: ChallengeEngine().buildSequence(pool: challengePool, randomize: randomizeChallenges),
            challengeTimeoutMillis: challengeTimeoutMillis, emitState: { [weak self] in self?.emit($0) },
            onComplete: { map in result(map) },
            onError: { error in result(FlutterError(code: error.errorCode.rawValue, message: error.message, details: nil)) }
        )
        runSession(session)
    }

    private func handleAuthenticate(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
        guard let userId = (call.arguments as? [String: Any])?["userId"] as? String else {
            throw BiometricException(.invalidConfiguration, "authenticate() requires userId.")
        }
        guard let enrolled = try storageOrThrow().get(userId: userId) else {
            throw BiometricException(.templateNotFound, "No enrollment found for '\(userId)'.")
        }
        guard enrolled.modelVersion == modelVersion, enrolled.embeddingDimension == embeddingDimension else {
            throw BiometricException(.templateDecryptionFailed, "Stored template was created by an incompatible model version; re-enrollment required.")
        }

        let session = AuthenticationSession(
            userId: userId, enrolledTemplate: enrolled, embeddingEngine: embeddingEngine!,
            antiSpoofEngine: antiSpoofEngine!, faceAlignment: faceAlignment, faceMatcher: faceMatcher,
            authenticationEngine: AuthenticationEngine(
                recognitionThreshold: recognitionThreshold, livenessThreshold: livenessThreshold,
                antiSpoofThreshold: antiSpoofThreshold, requireLiveness: enableLiveness, requireAntiSpoof: enableAntiSpoofing
            ),
            minimumFaceSize: minimumFaceSize, maximumFaceSize: maximumFaceSize, requireCenteredFace: requireCenteredFace,
            requireSingleFace: requireSingleFace, sessionTimeoutMillis: sessionTimeoutMillis, enableLiveness: enableLiveness,
            livenessSequence: ChallengeEngine().buildSequence(pool: challengePool, randomize: randomizeChallenges),
            challengeTimeoutMillis: challengeTimeoutMillis, emitState: { [weak self] in self?.emit($0) },
            onComplete: { map in result(map) },
            onError: { error in result(FlutterError(code: error.errorCode.rawValue, message: error.message, details: nil)) }
        )
        runSession(session)
    }

    private func handleVerifyLiveness(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
        let args = call.arguments as? [String: Any]
        let challengesArg = args?["challenges"] as? [String]
        let sequence: [LivenessChallenge]
        if let challengesArg = challengesArg {
            sequence = challengesArg.compactMap { LivenessChallenge(rawValue: $0) }
        } else {
            sequence = ChallengeEngine().buildSequence(pool: challengePool, randomize: randomizeChallenges)
        }
        let timeout = (args?["timeoutMs"] as? NSNumber)?.int64Value ?? sessionTimeoutMillis

        let session = LivenessSession(
            minimumFaceSize: minimumFaceSize,
            maximumFaceSize: maximumFaceSize,
            requireCenteredFace: requireCenteredFace,
            requireSingleFace: requireSingleFace,
            sessionTimeoutMillis: timeout,
            livenessSequence: sequence,
            challengeTimeoutMillis: challengeTimeoutMillis,
            emitState: { [weak self] in self?.emit($0) },
            emitChallengeProgress: { [weak self] in self?.emitProgress($0) },
            onComplete: { map in result(map) },
            onError: { error in result(FlutterError(code: error.errorCode.rawValue, message: error.message, details: nil)) }
        )
        runSession(session)
    }

    private func runSession(_ session: SessionRunner) {
        activeSession?.cancel()
        activeSession = session
        let manager = CameraManager()
        cameraManager = manager
        activeView?.attach(cameraManager: manager)
        manager.onFrame = { [weak session] image, detection in session?.onFrame(image, detection) }
        manager.onError = { [weak session] error in session?.fail(error) }
        emit(.initializing)
        manager.start(
            onReady: { [weak self] in
                guard let self = self else { return }
                self.activeView?.attach(cameraManager: manager)
                self.emit(.cameraReady)
            },
            onFailure: { [weak session] error in session?.fail(error) }
        )
    }

    private func handleCompare(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
        guard let args = call.arguments as? [String: Any],
              let firstData = args["firstImage"] as? FlutterStandardTypedData,
              let secondData = args["secondImage"] as? FlutterStandardTypedData else {
            throw BiometricException(.invalidConfiguration, "compare() requires firstImage and secondImage.")
        }
        guard let engine = embeddingEngine, engine.isAvailable else {
            throw BiometricException(.modelUnavailable, "compare() requires FaceBiometricConfig.embeddingModelAssetPath to be configured.")
        }

        embedStillImage(firstData.data, engine: engine) { [weak self] firstResult in
            guard let self = self else { return }
            switch firstResult {
            case .failure(let error):
                result(FlutterError(code: error.errorCode.rawValue, message: error.message, details: nil))
            case .success(let firstEmbedding):
                self.embedStillImage(secondData.data, engine: engine) { secondResult in
                    switch secondResult {
                    case .failure(let error):
                        result(FlutterError(code: error.errorCode.rawValue, message: error.message, details: nil))
                    case .success(let secondEmbedding):
                        do {
                            let match = try self.faceMatcher.match(firstEmbedding, secondEmbedding, threshold: self.recognitionThreshold)
                            result(["isMatch": match.isMatch, "similarity": match.similarity, "threshold": match.threshold])
                        } catch let error as BiometricException {
                            result(FlutterError(code: error.errorCode.rawValue, message: error.message, details: nil))
                        } catch {
                            result(FlutterError(code: FaceBiometricErrorCode.platformError.rawValue, message: error.localizedDescription, details: nil))
                        }
                    }
                }
            }
        }
    }

    /// Detects the single face in a still image, aligns it with the
    /// same `FaceAlignment` pipeline enrollment/authentication use,
    /// and generates its embedding. Asynchronous (Vision's request
    /// handler is callback-based), so the result is delivered via
    /// completion rather than a return value.
    private func embedStillImage(
        _ data: Data, engine: FaceEmbeddingEngine, completion: @escaping (Result<[Float], BiometricException>) -> Void
    ) {
        guard let image = UIImage(data: data) else {
            completion(.failure(BiometricException(.faceNotDetected, "Could not decode image bytes.")))
            return
        }
        let stillImageAnalyzer = FaceAnalyzer()
        stillImageAnalyzer.analyze(image: image) { detection in
            if detection.hasNoFace {
                completion(.failure(BiometricException(.faceNotDetected, "No face detected in the provided image.")))
                return
            }
            if detection.hasMultipleFaces {
                completion(.failure(BiometricException(.multipleFacesDetected, "Multiple faces detected in the provided image.")))
                return
            }
            guard let box = detection.boundingBox, detection.landmarks.count >= 2 else {
                completion(.failure(BiometricException(.embeddingGenerationFailed, "Could not locate eye landmarks in the provided image.")))
                return
            }
            do {
                let leftEyePx = CGPoint(
                    x: detection.landmarks[0].x * Double(image.size.width), y: detection.landmarks[0].y * Double(image.size.height)
                )
                let rightEyePx = CGPoint(
                    x: detection.landmarks[1].x * Double(image.size.width), y: detection.landmarks[1].y * Double(image.size.height)
                )
                let tensor = try self.faceAlignment.alignAndNormalize(
                    sourceImage: image,
                    boxLeft: Int(box.left * Double(image.size.width)), boxTop: Int(box.top * Double(image.size.height)),
                    boxWidth: Int(box.width * Double(image.size.width)), boxHeight: Int(box.height * Double(image.size.height)),
                    leftEyePx: leftEyePx, rightEyePx: rightEyePx
                )
                let embedding = try engine.generateEmbedding(alignedTensor: tensor)
                completion(.success(embedding))
            } catch let error as BiometricException {
                completion(.failure(error))
            } catch {
                completion(.failure(BiometricException(.embeddingGenerationFailed, "Failed to generate an embedding for the provided image.", underlying: error)))
            }
        }
    }

    private func handleDeviceBiometrics(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let reason = args?["reason"] as? String ?? "Authenticate"
        let authType = args?["authType"] as? String ?? "biometricOnly"

        let context = LAContext()
        let policy: LAPolicy = (authType == "biometricWithCredential" || authType == "deviceCredentialOnly")
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        var authError: NSError?
        guard context.canEvaluatePolicy(policy, error: &authError) else {
            result(false)
            return
        }
        context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { result(success) }
        }
    }
}
