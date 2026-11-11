package com.vinay.flutter_bio_auth

import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.vinay.flutter_bio_auth.model.AntiSpoofReason
import com.vinay.flutter_bio_auth.model.AntiSpoofResult
import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceAuthenticationFailureReason
import com.vinay.flutter_bio_auth.model.FaceBiometricErrorCode
import com.vinay.flutter_bio_auth.model.FaceDetectionResult
import com.vinay.flutter_bio_auth.model.FaceQualityResult
import com.vinay.flutter_bio_auth.model.FaceTemplateNative
import com.vinay.flutter_bio_auth.model.LivenessChallenge
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Wires the Dart `MethodChannel`/`EventChannel` contract
 * (lib/src/platform/face_biometric_platform.dart) to the native
 * engines. Orchestrates the full flow described in the README:
 * detect -> quality -> liveness -> anti-spoof -> align -> embed ->
 * match/store, entirely on-device, sending only structured state
 * (never raw frames) back to Flutter.
 */
class FaceBiometricPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var stateEventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private var activity: Activity? = null
    private var lifecycleOwner: LifecycleOwner? = null

    // Configuration, populated by initialize().
    private var recognitionThreshold = 0.68
    private var livenessThreshold = 0.80
    private var antiSpoofThreshold = 0.80
    private var enableLiveness = true
    private var enableAntiSpoofing = true
    private var challengePool: List<LivenessChallenge> = listOf(LivenessChallenge.blink)
    private var randomizeChallenges = true
    private var challengeTimeoutMillis = 30000L
    private var sessionTimeoutMillis = 60000L
    private var minimumFaceSize = 0.15
    private var maximumFaceSize = 0.85
    private var requireSingleFace = true
    private var requireCenteredFace = true
    private var mirrorPreview = true
    private var embeddingModelAssetPath: String? = null
    private var antiSpoofModelAssetPath: String? = null
    private var embeddingDimension = 192
    private var modelVersion = "face-model-1"

    private var cryptoManager: CryptoManager? = null
    private var storage: BiometricTemplateStorage? = null
    private var embeddingEngine: FaceEmbeddingEngine? = null
    private var antiSpoofEngine: AntiSpoofEngine? = null
    private var cameraManager: CameraManager? = null
    private val faceAlignment = FaceAlignment()
    private val faceMatcher = FaceMatcher()

    private var activeSession: SessionRunner? = null
    private var activeView: FaceBiometricView? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterPluginBinding
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_bio_auth/methods")
        methodChannel.setMethodCallHandler(this)
        stateEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_bio_auth/state_events")
        stateEventChannel.setStreamHandler(this)

        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "flutter_bio_auth/camera_preview",
            FaceBiometricViewFactory { context, lifecycle ->
                FaceBiometricView(context, lifecycle, mirrorPreview).also { view ->
                    activeView = view
                    view.onDispose = { if (activeView === view) activeView = null }
                    cameraManager?.let(view::attachCameraManager)
                }
            }.also { it.lifecycleProvider = { lifecycleOwner } },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        stateEventChannel.setStreamHandler(null)
        cameraManager?.dispose()
        embeddingEngine?.close()
        antiSpoofEngine?.close()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        lifecycleOwner = binding.activity as? LifecycleOwner
    }

    override fun onDetachedFromActivityForConfigChanges() { onDetachedFromActivity() }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
    override fun onDetachedFromActivity() {
        cameraManager?.stop()
        activity = null
        lifecycleOwner = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }

    private fun emitState(state: com.vinay.flutter_bio_auth.StateName) {
        val runnable = Runnable { eventSink?.success(state.wireValue) }
        activity?.runOnUiThread(runnable) ?: runnable.run()
    }

    private fun emitChallengeProgress(
        challenge: LivenessChallenge,
        instruction: String,
        progress: Double,
        confidence: Double,
        completed: Boolean,
        timedOut: Boolean,
    ) {
        val payload = mapOf(
            "state" to StateName.CHALLENGE_IN_PROGRESS.wireValue,
            "challenge" to challenge.name,
            "instruction" to instruction,
            "progress" to progress,
            "confidence" to confidence,
            "completed" to completed,
            "timedOut" to timedOut,
        )
        val runnable = Runnable { eventSink?.success(payload) }
        activity?.runOnUiThread(runnable) ?: runnable.run()
    }

    // ------------------------------------------------------------------
    // MethodChannel dispatch
    // ------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> handleInitialize(call, result)
                "enroll" -> handleEnroll(call, result)
                "authenticate" -> handleAuthenticate(call, result)
                "verifyLiveness" -> handleVerifyLiveness(call, result)
                "compare" -> handleCompare(call, result)
                "isEnrolled" -> result.success(storageOrThrow().exists(call.argument<String>("userId")!!))
                "deleteEnrollment" -> { storageOrThrow().delete(call.argument<String>("userId")!!); result.success(null) }
                "getEnrolledUsers" -> result.success(storageOrThrow().getUsers())
                "clearAllEnrollments" -> { storageOrThrow().clear(); result.success(null) }
                "authenticateWithDeviceBiometrics" -> handleDeviceBiometrics(call, result)
                "startFaceDetection" -> handleStartFaceDetection(call, result)
                "stopFaceDetection" -> handleStopFaceDetection(result)
                "switchModel" -> handleSwitchModel(call, result)
                "retry" -> { activeSession?.reset(); result.success(null) }
                "dispose" -> { handleDispose(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (e: BiometricException) {
            result.error(e.errorCode.name, e.message, null)
        } catch (e: Exception) {
            result.error(FaceBiometricErrorCode.platformError.name, e.message, null)
        }
    }

    private fun storageOrThrow(): BiometricTemplateStorage =
        storage ?: throw BiometricException(FaceBiometricErrorCode.platformError, "Call initialize() first.")

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as Map<*, *>
        recognitionThreshold = (args["recognitionThreshold"] as Number).toDouble()
        livenessThreshold = (args["livenessThreshold"] as Number).toDouble()
        antiSpoofThreshold = (args["antiSpoofThreshold"] as Number).toDouble()
        enableLiveness = args["enableLiveness"] as Boolean
        enableAntiSpoofing = args["enableAntiSpoofing"] as Boolean
        @Suppress("UNCHECKED_CAST")
        challengePool = (args["challenges"] as List<String>).map { LivenessChallenge.valueOf(it) }
        randomizeChallenges = args["randomizeChallenges"] as Boolean
        challengeTimeoutMillis = (args["challengeTimeoutMs"] as Number).toLong()
        sessionTimeoutMillis = (args["sessionTimeoutMs"] as Number).toLong()
        minimumFaceSize = (args["minimumFaceSize"] as Number).toDouble()
        maximumFaceSize = (args["maximumFaceSize"] as Number).toDouble()
        requireSingleFace = args["requireSingleFace"] as Boolean
        requireCenteredFace = args["requireCenteredFace"] as Boolean
        mirrorPreview = args["mirrorPreview"] as Boolean
        embeddingModelAssetPath = args["embeddingModelAssetPath"] as String?
        antiSpoofModelAssetPath = args["antiSpoofModelAssetPath"] as String?
        embeddingDimension = (args["embeddingDimension"] as Number).toInt()

        val crypto = CryptoManager()
        cryptoManager = crypto
        storage = SharedPreferencesTemplateStorage(binding.applicationContext, crypto)

        val assetManager = binding.applicationContext.assets
        val resolvedEmbeddingPath = embeddingModelAssetPath?.let { binding.flutterAssets.getAssetFilePathBySubpath(it) }
        val resolvedAntiSpoofPath = antiSpoofModelAssetPath?.let { binding.flutterAssets.getAssetFilePathBySubpath(it) }

        embeddingEngine = if (resolvedEmbeddingPath != null) {
            TFLiteFaceEmbeddingEngine(assetManager, resolvedEmbeddingPath, modelVersion, embeddingDimension)
        } else {
            UnavailableFaceEmbeddingEngine(modelVersion, embeddingDimension)
        }
        antiSpoofEngine = if (resolvedAntiSpoofPath != null) {
            TFLiteAntiSpoofEngine(assetManager, resolvedAntiSpoofPath)
        } else {
            UnavailableAntiSpoofEngine()
        }

        result.success(null)
    }

    private fun handleDispose() {
        activeSession?.cancel()
        activeSession = null
        cameraManager?.dispose()
        cameraManager = null
    }

    // ------------------------------------------------------------------
    // Enrollment / Authentication session orchestration
    // ------------------------------------------------------------------

    private fun handleEnroll(call: MethodCall, result: MethodChannel.Result) {
        val userId = call.argument<String>("userId")!!
        val reqLiveness = call.argument<Boolean>("enableLiveness") ?: enableLiveness
        val owner = lifecycleOwner ?: return result.error(
            FaceBiometricErrorCode.platformError.name, "No activity attached.", null,
        )
        if (!hasCameraPermission()) {
            emitState(StateName.PERMISSION_DENIED)
            return result.error(FaceBiometricErrorCode.cameraPermissionDenied.name, "Camera permission not granted.", null)
        }

        val session = EnrollmentSession(
            userId = userId,
            embeddingEngine = embeddingEngine!!,
            faceAlignment = faceAlignment,
            storage = storageOrThrow(),
            minimumFaceSize = minimumFaceSize,
            maximumFaceSize = maximumFaceSize,
            requireCenteredFace = requireCenteredFace,
            requireSingleFace = requireSingleFace,
            requiredSamples = 5,
            sessionTimeoutMillis = sessionTimeoutMillis,
            enableLiveness = reqLiveness,
            livenessSequence = ChallengeEngine().buildSequence(challengePool, randomizeChallenges),
            challengeTimeoutMillis = challengeTimeoutMillis,
            emitState = ::emitState,
            emitChallengeProgress = ::emitChallengeProgress,
            onComplete = { mapResult -> result.success(mapResult) },
            onError = { e -> result.error(e.errorCode.name, e.message, null) },
        )
        runSession(owner, session)
    }

    private fun handleAuthenticate(call: MethodCall, result: MethodChannel.Result) {
        val userId = call.argument<String>("userId")!!
        val reqLiveness = call.argument<Boolean>("enableLiveness") ?: enableLiveness
        val owner = lifecycleOwner ?: return result.error(
            FaceBiometricErrorCode.platformError.name, "No activity attached.", null,
        )
        if (!hasCameraPermission()) {
            emitState(StateName.PERMISSION_DENIED)
            return result.error(FaceBiometricErrorCode.cameraPermissionDenied.name, "Camera permission not granted.", null)
        }

        val enrolled = storageOrThrow().get(userId) ?: return result.error(
            FaceBiometricErrorCode.templateNotFound.name, "No enrollment found for '$userId'.", null,
        )
        if (!enrolled.modelVersion.equals(modelVersion) || enrolled.embeddingDimension != embeddingDimension) {
            return result.error(
                FaceBiometricErrorCode.templateDecryptionFailed.name,
                "Stored template was created by an incompatible model version; re-enrollment required.",
                null,
            )
        }

        val session = AuthenticationSession(
            userId = userId,
            enrolledTemplate = enrolled,
            embeddingEngine = embeddingEngine!!,
            antiSpoofEngine = antiSpoofEngine!!,
            faceAlignment = faceAlignment,
            faceMatcher = faceMatcher,
            authenticationEngine = AuthenticationEngine(
                recognitionThreshold = recognitionThreshold,
                livenessThreshold = livenessThreshold,
                antiSpoofThreshold = antiSpoofThreshold,
                requireLiveness = reqLiveness,
                requireAntiSpoof = enableAntiSpoofing,
            ),
            minimumFaceSize = minimumFaceSize,
            maximumFaceSize = maximumFaceSize,
            requireCenteredFace = requireCenteredFace,
            requireSingleFace = requireSingleFace,
            sessionTimeoutMillis = sessionTimeoutMillis,
            enableLiveness = reqLiveness,
            livenessSequence = ChallengeEngine().buildSequence(challengePool, randomizeChallenges),
            challengeTimeoutMillis = challengeTimeoutMillis,
            emitState = ::emitState,
            emitChallengeProgress = ::emitChallengeProgress,
            onComplete = { mapResult -> result.success(mapResult) },
            onError = { e -> result.error(e.errorCode.name, e.message, null) },
        )
        runSession(owner, session)
    }

    private fun handleStartFaceDetection(call: MethodCall, result: MethodChannel.Result) {
        val owner = lifecycleOwner ?: return result.error(
            FaceBiometricErrorCode.platformError.name, "No activity attached.", null,
        )
        if (!hasCameraPermission()) {
            emitState(StateName.PERMISSION_DENIED)
            return result.error(FaceBiometricErrorCode.cameraPermissionDenied.name, "Camera permission not granted.", null)
        }

        activeSession?.cancel()
        val manager = CameraManager(binding.applicationContext, owner)
        cameraManager = manager
        activeView?.attachCameraManager(manager)
        manager.requiresBitmapProvider = { true }
        manager.onFrame = { bitmap, detection, _ ->
            var torsoR = 0
            var torsoG = 0
            var torsoB = 0
            var hasTorso = false
            var hasHelmet = false
            var helmetScore = 0.0

            val box = detection.boundingBox
            if (box != null && bitmap != null && !detection.hasNoFace) {
                val bWidth = bitmap.width
                val bHeight = bitmap.height
                val faceW = (box.width * bWidth).toInt().coerceAtLeast(1)
                val faceH = (box.height * bHeight).toInt().coerceAtLeast(1)
                val faceLeft = (box.left * bWidth).toInt()
                val faceTop = (box.top * bHeight).toInt()
                val faceBottom = faceTop + faceH
                val faceCenterX = faceLeft + faceW / 2

                // 1. Torso sampling (below chin)
                val torsoTop = (faceBottom + faceH * 0.18).toInt().coerceIn(0, bHeight - 1)
                val torsoBottom = (faceBottom + faceH * 1.55).toInt().coerceIn(torsoTop + 1, bHeight)
                val torsoWidth = (faceW * 0.90).toInt().coerceIn(10, bWidth)
                val torsoLeft = (faceCenterX - torsoWidth / 2).coerceIn(0, bWidth - torsoWidth)
                val torsoRight = (torsoLeft + torsoWidth).coerceIn(torsoLeft + 1, bWidth)

                if (torsoBottom > torsoTop && torsoRight > torsoLeft) {
                    var rSum = 0L
                    var gSum = 0L
                    var bSum = 0L
                    var count = 0
                    val stepX = ((torsoRight - torsoLeft) / 12).coerceAtLeast(1)
                    val stepY = ((torsoBottom - torsoTop) / 12).coerceAtLeast(1)

                    for (y in torsoTop until torsoBottom step stepY) {
                        for (x in torsoLeft until torsoRight step stepX) {
                            val pixel = bitmap.getPixel(x, y)
                            rSum += (pixel shr 16) and 0xFF
                            gSum += (pixel shr 8) and 0xFF
                            bSum += pixel and 0xFF
                            count++
                        }
                    }
                    if (count > 0) {
                        torsoR = (rSum / count).toInt()
                        torsoG = (gSum / count).toInt()
                        torsoB = (bSum / count).toInt()
                        hasTorso = true
                    }
                }

                // 2. Headgear / Helmet analysis (above forehead)
                val headTop = (faceTop - faceH * 0.45).toInt().coerceIn(0, bHeight - 1)
                val headBottom = (faceTop - faceH * 0.05).toInt().coerceIn(headTop + 1, bHeight)
                val headLeft = (faceCenterX - faceW * 0.40).toInt().coerceIn(0, bWidth - 1)
                val headRight = (faceCenterX + faceW * 0.40).toInt().coerceIn(headLeft + 1, bWidth)

                if (headBottom > headTop && headRight > headLeft) {
                    var nonSkinCount = 0
                    var totalHead = 0
                    val hStepX = ((headRight - headLeft) / 8).coerceAtLeast(1)
                    val hStepY = ((headBottom - headTop) / 8).coerceAtLeast(1)

                    for (y in headTop until headBottom step hStepY) {
                        for (x in headLeft until headRight step hStepX) {
                            val pixel = bitmap.getPixel(x, y)
                            val r = (pixel shr 16) and 0xFF
                            val g = (pixel shr 8) and 0xFF
                            val b = pixel and 0xFF
                            val isSkin = r > 95 && g > 40 && b > 20 &&
                                    (r - g) > 15 && r > g && g > b
                            if (!isSkin) nonSkinCount++
                            totalHead++
                        }
                    }
                    if (totalHead > 0) {
                        helmetScore = nonSkinCount.toDouble() / totalHead
                        hasHelmet = helmetScore > 0.45
                    }
                }
            }

            val payload = mapOf(
                "state" to if (detection.hasNoFace) StateName.DETECTING_FACE.wireValue else StateName.FACE_DETECTED.wireValue,
                "smilingProbability" to (detection.smilingProbability ?: 0.0),
                "leftEyeOpenProbability" to (detection.leftEyeOpenProbability ?: 0.0),
                "rightEyeOpenProbability" to (detection.rightEyeOpenProbability ?: 0.0),
                "yawDegrees" to (detection.yawDegrees ?: 0.0),
                "pitchDegrees" to (detection.pitchDegrees ?: 0.0),
                "rollDegrees" to (detection.rollDegrees ?: 0.0),
                "faceCount" to detection.faceCount,
                "hasFace" to !detection.hasNoFace,
                "hasTorso" to hasTorso,
                "torsoR" to torsoR,
                "torsoG" to torsoG,
                "torsoB" to torsoB,
                "hasHelmet" to hasHelmet,
                "helmetScore" to helmetScore,
            )
            val runnable = Runnable { eventSink?.success(payload) }
            activity?.runOnUiThread(runnable) ?: runnable.run()
        }
        manager.onError = {
            emitState(StateName.ERROR)
        }
        emitState(StateName.INITIALIZING)
        manager.start(
            onReady = {
                activeView?.attachCameraManager(manager)
                emitState(StateName.CAMERA_READY)
            },
            onFailure = {
                emitState(StateName.ERROR)
            },
        )
        result.success(null)
    }

    private fun handleStopFaceDetection(result: MethodChannel.Result) {
        cameraManager?.stop()
        emitState(StateName.IDLE)
        result.success(null)
    }

    private fun handleSwitchModel(call: MethodCall, result: MethodChannel.Result) {
        val assetPath = call.argument<String>("assetPath")
        val dim = (call.argument<Number>("embeddingDimension"))?.toInt() ?: 192
        val version = call.argument<String>("modelVersion") ?: "face-model-1"
        val threshold = (call.argument<Number>("threshold"))?.toDouble() ?: recognitionThreshold

        embeddingDimension = dim
        modelVersion = version
        recognitionThreshold = threshold
        embeddingModelAssetPath = assetPath

        val assetManager = binding.applicationContext.assets
        val resolvedPath = assetPath?.let { binding.flutterAssets.getAssetFilePathBySubpath(it) }
        embeddingEngine?.close()
        embeddingEngine = if (resolvedPath != null) {
            TFLiteFaceEmbeddingEngine(assetManager, resolvedPath, modelVersion, embeddingDimension)
        } else {
            UnavailableFaceEmbeddingEngine(modelVersion, embeddingDimension)
        }
        result.success(true)
    }

    private fun handleVerifyLiveness(call: MethodCall, result: MethodChannel.Result) {
        val owner = lifecycleOwner ?: return result.error(
            FaceBiometricErrorCode.platformError.name, "No activity attached.", null,
        )
        if (!hasCameraPermission()) {
            emitState(StateName.PERMISSION_DENIED)
            return result.error(FaceBiometricErrorCode.cameraPermissionDenied.name, "Camera permission not granted.", null)
        }

        val args = call.arguments as? Map<*, *>
        val challengesArg = args?.get("challenges") as? List<*>
        val sequence = if (challengesArg != null) {
            challengesArg.map { LivenessChallenge.valueOf(it as String) }
        } else {
            ChallengeEngine().buildSequence(challengePool, randomizeChallenges)
        }
        val timeout = (args?.get("timeoutMs") as? Number)?.toLong() ?: sessionTimeoutMillis

        val session = LivenessSession(
            minimumFaceSize = minimumFaceSize,
            maximumFaceSize = maximumFaceSize,
            requireCenteredFace = requireCenteredFace,
            requireSingleFace = requireSingleFace,
            sessionTimeoutMillis = timeout,
            livenessSequence = sequence,
            challengeTimeoutMillis = maxOf(timeout, challengeTimeoutMillis),
            emitState = ::emitState,
            emitChallengeProgress = ::emitChallengeProgress,
            onComplete = { mapResult -> result.success(mapResult) },
            onError = { e -> result.error(e.errorCode.name, e.message, null) },
        )
        runSession(owner, session)
    }

    private fun runSession(owner: LifecycleOwner, session: SessionRunner) {
        activeSession?.cancel()
        activeSession = session
        val manager = CameraManager(binding.applicationContext, owner)
        cameraManager = manager
        activeView?.attachCameraManager(manager)
        manager.requiresBitmapProvider = { activeSession?.requiresBitmap == true }
        manager.onFrame = { bitmap, detection, rotation -> session.onFrame(bitmap, detection) }
        manager.onError = { e -> session.fail(e) }
        emitState(StateName.INITIALIZING)
        manager.start(
            onReady = {
                activeView?.attachCameraManager(manager)
                emitState(StateName.CAMERA_READY)
            },
            onFailure = { e -> session.fail(e) },
        )
    }

    private fun decodeUprightBitmap(bytes: ByteArray): Bitmap? {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        return try {
            val exif = androidx.exifinterface.media.ExifInterface(java.io.ByteArrayInputStream(bytes))
            val orientation = exif.getAttributeInt(
                androidx.exifinterface.media.ExifInterface.TAG_ORIENTATION,
                androidx.exifinterface.media.ExifInterface.ORIENTATION_NORMAL,
            )
            val matrix = android.graphics.Matrix()
            when (orientation) {
                androidx.exifinterface.media.ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                androidx.exifinterface.media.ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                androidx.exifinterface.media.ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                androidx.exifinterface.media.ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                androidx.exifinterface.media.ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
                androidx.exifinterface.media.ExifInterface.ORIENTATION_TRANSPOSE -> {
                    matrix.postRotate(90f)
                    matrix.postScale(-1f, 1f)
                }
                androidx.exifinterface.media.ExifInterface.ORIENTATION_TRANSVERSE -> {
                    matrix.postRotate(270f)
                    matrix.postScale(-1f, 1f)
                }
                else -> return bitmap
            }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated != bitmap) {
                bitmap.recycle()
            }
            rotated
        } catch (e: Exception) {
            bitmap
        }
    }

    private fun handleCompare(call: MethodCall, result: MethodChannel.Result) {
        val firstImageBytes = call.argument<ByteArray>("firstImage")
        val secondImageBytes = call.argument<ByteArray>("secondImage")
        if (firstImageBytes == null || secondImageBytes == null) {
            result.error(
                FaceBiometricErrorCode.invalidConfiguration.name,
                "compare() requires firstImage and secondImage.",
                null,
            )
            return
        }
        val engine = embeddingEngine
        if (engine == null || !engine.isAvailable) {
            result.error(
                FaceBiometricErrorCode.modelUnavailable.name,
                "compare() requires FaceBiometricConfig.embeddingModelAssetPath to be configured.",
                null,
            )
            return
        }

        embedStillImageAsync(
            firstImageBytes,
            engine,
            onSuccess = { firstEmbedding ->
                embedStillImageAsync(
                    secondImageBytes,
                    engine,
                    onSuccess = { secondEmbedding ->
                        try {
                            val match = faceMatcher.match(firstEmbedding, secondEmbedding, recognitionThreshold)
                            result.success(
                                mapOf(
                                    "isMatch" to match.isMatch,
                                    "similarity" to match.similarity,
                                    "threshold" to match.threshold,
                                ),
                            )
                        } catch (e: BiometricException) {
                            result.error(e.errorCode.name, e.message, null)
                        }
                    },
                    onError = { e -> result.error(e.errorCode.name, e.message, null) },
                )
            },
            onError = { e -> result.error(e.errorCode.name, e.message, null) },
        )
    }

    /**
     * Detects the single face in a still image, aligns it with the
     * same [FaceAlignment] pipeline enrollment/authentication use, and
     * generates its embedding. Asynchronous (ML Kit's still-image
     * detection is Task-based like the live path), so results are
     * delivered via callback rather than a return value.
     */
    private fun embedStillImageAsync(
        bytes: ByteArray,
        engine: FaceEmbeddingEngine,
        onSuccess: (FloatArray) -> Unit,
        onError: (BiometricException) -> Unit,
    ) {
        val bitmap = decodeUprightBitmap(bytes)
        if (bitmap == null) {
            onError(BiometricException(FaceBiometricErrorCode.faceNotDetected, "Could not decode image bytes."))
            return
        }

        val stillImageAnalyzer = FaceAnalyzer()
        stillImageAnalyzer.analyzeBitmap(
            bitmap,
            onResult = { detection ->
                stillImageAnalyzer.close()
                when {
                    detection.hasNoFace -> onError(
                        BiometricException(FaceBiometricErrorCode.faceNotDetected, "No face detected in the provided image."),
                    )
                    detection.hasMultipleFaces -> onError(
                        BiometricException(
                            FaceBiometricErrorCode.multipleFacesDetected,
                            "Multiple faces detected in the provided image.",
                        ),
                    )
                    else -> {
                        val box = detection.boundingBox
                        val landmarks = detection.landmarks
                        if (box == null || landmarks.size < 2) {
                            onError(
                                BiometricException(
                                    FaceBiometricErrorCode.embeddingGenerationFailed,
                                    "Could not locate eye landmarks in the provided image.",
                                ),
                            )
                        } else {
                            try {
                                val leftEyePx = Pair(
                                    (landmarks[0].x * bitmap.width).toFloat(),
                                    (landmarks[0].y * bitmap.height).toFloat(),
                                )
                                val rightEyePx = Pair(
                                    (landmarks[1].x * bitmap.width).toFloat(),
                                    (landmarks[1].y * bitmap.height).toFloat(),
                                )
                                val tensor = faceAlignment.alignAndNormalize(
                                    sourceBitmap = bitmap,
                                    boxLeft = (box.left * bitmap.width).toInt(),
                                    boxTop = (box.top * bitmap.height).toInt(),
                                    boxWidth = (box.width * bitmap.width).toInt(),
                                    boxHeight = (box.height * bitmap.height).toInt(),
                                    leftEyePx = leftEyePx,
                                    rightEyePx = rightEyePx,
                                )
                                onSuccess(engine.generateEmbedding(tensor))
                            } catch (e: BiometricException) {
                                onError(e)
                            }
                        }
                    }
                }
            },
            onError = { throwable ->
                stillImageAnalyzer.close()
                onError(
                    BiometricException(
                        FaceBiometricErrorCode.faceNotDetected,
                        "Face detection failed on the provided image.",
                        throwable,
                    ),
                )
            },
        )
    }

    private fun handleDeviceBiometrics(call: MethodCall, result: MethodChannel.Result) {
        val activity = this.activity as? androidx.fragment.app.FragmentActivity
        if (activity == null) {
            result.error(FaceBiometricErrorCode.platformError.name, "Device biometrics require a FragmentActivity host.", null)
            return
        }
        val reason = call.argument<String>("reason") ?: "Authenticate"
        val authType = call.argument<String>("authType") ?: "biometricOnly"
        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = androidx.biometric.BiometricPrompt(
            activity, executor,
            object : androidx.biometric.BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(res: androidx.biometric.BiometricPrompt.AuthenticationResult) {
                    result.success(true)
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    result.success(false)
                }
                override fun onAuthenticationFailed() {
                    // Allow BiometricPrompt's own retry UI to continue;
                    // do not resolve the Flutter result yet.
                }
            },
        )
        val promptBuilder = androidx.biometric.BiometricPrompt.PromptInfo.Builder()
            .setTitle(reason)

        when (authType) {
            "deviceCredentialOnly" -> {
                promptBuilder.setAllowedAuthenticators(
                    androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
                )
            }
            "strongBiometricOnly" -> {
                promptBuilder.setAllowedAuthenticators(
                    androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
                )
                promptBuilder.setNegativeButtonText("Cancel")
            }
            "biometricWithCredential" -> {
                promptBuilder.setAllowedAuthenticators(
                    androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
                )
            }
            else -> { // "biometricOnly"
                promptBuilder.setAllowedAuthenticators(
                    androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
                )
                promptBuilder.setNegativeButtonText("Cancel")
            }
        }

        try {
            prompt.authenticate(promptBuilder.build())
        } catch (e: Exception) {
            android.util.Log.e("FaceBiometric", "BiometricPrompt failed: ${e.message}", e)
            result.error(FaceBiometricErrorCode.platformError.name, e.message, null)
        }
    }

    private fun hasCameraPermission(): Boolean {
        val ctx = activity ?: binding.applicationContext
        return ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }
}

/** Bridges Flutter's typed `AndroidView` registration to a factory
 *  needing a lifecycle owner resolved lazily (the Activity may attach
 *  after the view factory is registered at engine-attach time). */
private class FaceBiometricViewFactory(
    private val make: (android.content.Context, LifecycleOwner) -> FaceBiometricView,
) : io.flutter.plugin.platform.PlatformViewFactory(io.flutter.plugin.common.StandardMessageCodec.INSTANCE) {
    var lifecycleProvider: (() -> LifecycleOwner?)? = null
    override fun create(context: android.content.Context, viewId: Int, args: Any?): io.flutter.plugin.platform.PlatformView {
        val owner = lifecycleProvider?.invoke()
            ?: throw IllegalStateException("Camera preview requested before an Activity was attached.")
        return make(context, owner)
    }
}

/** Wire-format state names, matching lib/src/face_biometric_state.dart
 *  `FaceBiometricState` enum member names exactly. */
enum class StateName(val wireValue: String) {
    IDLE("idle"), INITIALIZING("initializing"), REQUESTING_PERMISSION("requestingPermission"),
    CAMERA_READY("cameraReady"), DETECTING_FACE("detectingFace"), FACE_DETECTED("faceDetected"),
    VALIDATING_FACE("validatingFace"), RUNNING_LIVENESS("runningLiveness"),
    CHALLENGE_IN_PROGRESS("challengeInProgress"), GENERATING_EMBEDDING("generatingEmbedding"),
    MATCHING_FACE("matchingFace"), CHECKING_ANTI_SPOOF("checkingAntiSpoof"),
    AUTHENTICATING("authenticating"), SUCCESS("success"), FAILED("failed"), TIMEOUT("timeout"),
    PERMISSION_DENIED("permissionDenied"), ERROR("error"),
}
