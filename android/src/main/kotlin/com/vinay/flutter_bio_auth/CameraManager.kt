package com.vinay.flutter_bio_auth

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceBiometricErrorCode
import com.vinay.flutter_bio_auth.model.FaceDetectionResult
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Owns the CameraX session: front camera selection, lifecycle
 * binding, frame throttling (adaptive ~10-15 FPS analysis even though
 * the sensor runs at 30 FPS), and correct [ImageProxy] closing so no
 * buffers or frames are ever retained past their analysis window. Raw
 * frames never leave this class -- [FaceAnalyzer] output
 * ([FaceDetectionResult]) is the only thing handed upward.
 */
class CameraManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
) {
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val faceAnalyzer = FaceAnalyzer()

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var imageAnalysis: ImageAnalysis? = null
    var preview: Preview? = null
        private set

    private val processingFrame = AtomicBoolean(false)
    private var lastAnalysisTimestampMillis = 0L

    /** Spacing between analyzed frames (~22 FPS); sensor runs at 30 FPS for preview. */
    private val minAnalysisIntervalMillis = 45L

    /** Callback to query whether the active session requires a full Bitmap for this frame. */
    var requiresBitmapProvider: (() -> Boolean)? = null

    /** Callback invoked with the latest (optional) bitmap + detection whenever a
     *  frame is analyzed. */
    var onFrame: ((Bitmap?, FaceDetectionResult, rotationDegrees: Int) -> Unit)? = null
    var onError: ((BiometricException) -> Unit)? = null

    fun start(onReady: () -> Unit, onFailure: (BiometricException) -> Unit) {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                cameraProvider = provider
                bindUseCases(provider)
                onReady()
            } catch (e: Exception) {
                onFailure(
                    BiometricException(FaceBiometricErrorCode.cameraUnavailable, "Failed to start the camera.", e),
                )
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun getDisplayRotation(): Int {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? android.view.WindowManager
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            try {
                context.display?.rotation ?: android.view.Surface.ROTATION_0
            } catch (e: Exception) {
                android.view.Surface.ROTATION_0
            }
        } else {
            @Suppress("DEPRECATION")
            wm?.defaultDisplay?.rotation ?: android.view.Surface.ROTATION_0
        }
    }

    private fun bindUseCases(provider: ProcessCameraProvider) {
        provider.unbindAll()

        val selector = CameraSelector.Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
            .build()

        val rotation = getDisplayRotation()

        val previewUseCase = Preview.Builder()
            .setTargetRotation(rotation)
            .build()
        preview = previewUseCase
        onPreviewConfigured?.invoke(previewUseCase)

        val analysis = ImageAnalysis.Builder()
            .setTargetRotation(rotation)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
        analysis.setAnalyzer(analysisExecutor) { imageProxy -> onImageProxy(imageProxy) }
        imageAnalysis = analysis

        try {
            camera = provider.bindToLifecycle(lifecycleOwner, selector, previewUseCase, analysis)
        } catch (e: Exception) {
            throw BiometricException(FaceBiometricErrorCode.cameraUnavailable, "No compatible front camera available.", e)
        }
    }

    var onPreviewConfigured: ((Preview) -> Unit)? = null

    private fun onImageProxy(imageProxy: ImageProxy) {
        val now = System.currentTimeMillis()
        val dueForAnalysis = now - lastAnalysisTimestampMillis >= minAnalysisIntervalMillis

        if (!dueForAnalysis || !processingFrame.compareAndSet(false, true)) {
            // Throttled or a previous frame is still in flight -- drop
            // this one rather than queueing, per STRATEGY_KEEP_ONLY_LATEST.
            imageProxy.close()
            return
        }
        lastAnalysisTimestampMillis = now

        try {
            faceAnalyzer.analyze(
                imageProxy,
                onResult = { result ->
                    try {
                        val bitmap = if (requiresBitmapProvider?.invoke() == true) {
                            imageProxy.toSafeBitmap()
                        } else {
                            null
                        }
                        onFrame?.invoke(bitmap, result, imageProxy.imageInfo.rotationDegrees)
                    } finally {
                        processingFrame.set(false)
                        imageProxy.close()
                    }
                },
                onError = { e ->
                    processingFrame.set(false)
                    imageProxy.close()
                    onError?.invoke(BiometricException(FaceBiometricErrorCode.platformError, "Face detection failed on a frame.", e))
                },
            )
        } catch (e: Exception) {
            processingFrame.set(false)
            imageProxy.close()
            Log.w("FaceBiometric", "Dropped a frame after an analyzer exception.", e)
        }
    }

    /** Stops analysis and unbinds all camera use cases. Safe to call
     *  from onPause/onStop. Does not release the analyzer's ML Kit
     *  detector -- call [dispose] for that. */
    fun stop() {
        cameraProvider?.unbindAll()
    }

    /** Full teardown: stops the camera, releases the ML Kit detector,
     *  and shuts down the analysis executor. */
    fun dispose() {
        stop()
        faceAnalyzer.close()
        analysisExecutor.shutdown()
    }
}

/**
 * Converts an [ImageProxy] to an upright [Bitmap] for alignment/embedding.
 * Uses CameraX's built-in [ImageProxy.toBitmap] for fast and robust conversion.
 */
private fun ImageProxy.toSafeBitmap(): Bitmap? {
    return try {
        val bitmap = toBitmap()
        val rotation = imageInfo.rotationDegrees
        if (rotation == 0) return bitmap
        val matrix = android.graphics.Matrix().apply { postRotate(rotation.toFloat()) }
        Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    } catch (e: Exception) {
        null
    }
}
