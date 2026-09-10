package com.vinay.flutter_bio_auth

import android.content.res.AssetManager
import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceBiometricErrorCode
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

/**
 * Generates a face embedding from an aligned/normalized face tensor
 * (see [FaceAlignment]). Deliberately an interface, not a class, so
 * the model can be swapped without touching enrollment/authentication
 * logic (see README "Fallback model architecture").
 */
interface FaceEmbeddingEngine {
    /** True once a real model is loaded and ready to generate
     *  embeddings. Callers MUST check this before calling
     *  [generateEmbedding] and surface [FaceBiometricErrorCode.modelUnavailable]
     *  rather than calling it anyway. */
    val isAvailable: Boolean

    val modelVersion: String
    val embeddingDimension: Int

    /** @throws BiometricException(embeddingGenerationFailed) if the
     *  model produces unusable output, or (modelUnavailable) if called
     *  while [isAvailable] is false. Never returns a random/fabricated
     *  vector. */
    fun generateEmbedding(alignedTensor: FloatArray): FloatArray

    fun close()
}

/**
 * Real implementation: loads a `.tflite` file from a Flutter asset
 * path the *consuming app* declares in its own `pubspec.yaml`
 * (matching [FaceBiometricConfig.embeddingModelAssetPath]). The plugin
 * itself ships no model bytes.
 *
 * Free, permissively-licensed starting points you can convert to
 * TFLite and bundle this way: MediaPipe's Apache-2.0 face models
 * (https://ai.google.dev/edge/mediapipe) or a community TFLite/ONNX
 * export of MobileFaceNet / ArcFace-mobile. See README "Model
 * installation" for exact input/output tensor requirements this class
 * expects.
 */
class TFLiteFaceEmbeddingEngine(
    assetManager: AssetManager,
    flutterAssetPath: String?,
    override val modelVersion: String,
    override val embeddingDimension: Int,
) : FaceEmbeddingEngine {

    private var interpreter: Interpreter? = null

    override val isAvailable: Boolean
        get() = interpreter != null

    init {
        if (!flutterAssetPath.isNullOrBlank()) {
            try {
                val buffer = loadModelBuffer(assetManager, flutterAssetPath)
                val options = Interpreter.Options().apply {
                    setNumThreads(4)
                }
                interpreter = Interpreter(buffer, options)
                android.util.Log.i("FaceBiometric", "Successfully loaded face embedding model from $flutterAssetPath")
            } catch (e: Exception) {
                android.util.Log.e("FaceBiometric", "Failed to load face embedding model from $flutterAssetPath: ${e.message}", e)
                interpreter = null
            }
        }
    }

    private fun loadModelBuffer(assetManager: AssetManager, assetPath: String): ByteBuffer {
        val file = java.io.File(assetPath)
        if (file.exists() && file.isFile) {
            java.io.FileInputStream(file).use { input ->
                val channel = input.channel
                return channel.map(FileChannel.MapMode.READ_ONLY, 0, channel.size())
            }
        }
        return try {
            val fd = assetManager.openFd(assetPath)
            java.io.FileInputStream(fd.fileDescriptor).use { input ->
                val channel = input.channel
                channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
            }
        } catch (e: Exception) {
            assetManager.open(assetPath).use { input ->
                val bytes = input.readBytes()
                val buffer = ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder())
                buffer.put(bytes)
                buffer.rewind()
                buffer
            }
        }
    }

    override fun generateEmbedding(alignedTensor: FloatArray): FloatArray {
        val engine = interpreter ?: throw BiometricException(
            FaceBiometricErrorCode.modelUnavailable,
            "No embedding model loaded. Configure " +
                "FaceBiometricConfig.embeddingModelAssetPath with a valid " +
                "asset path to a .tflite face-embedding model.",
        )

        val inputBuffer = ByteBuffer.allocateDirect(alignedTensor.size * 4)
            .order(ByteOrder.nativeOrder())
        inputBuffer.asFloatBuffer().put(alignedTensor)
        inputBuffer.rewind()

        val output = Array(1) { FloatArray(embeddingDimension) }
        try {
            engine.run(inputBuffer, output)
        } catch (e: Exception) {
            android.util.Log.e("FaceBiometric", "Embedding inference failed: ${e.message}", e)
            throw BiometricException(
                FaceBiometricErrorCode.embeddingGenerationFailed,
                "The embedding model failed to run on the aligned face tensor: ${e.message}",
                e,
            )
        }

        val raw = output[0]
        if (raw.size != embeddingDimension || raw.any { it.isNaN() || it.isInfinite() }) {
            throw BiometricException(
                FaceBiometricErrorCode.embeddingGenerationFailed,
                "Embedding model produced an invalid output vector " +
                    "(expected dimension $embeddingDimension, got ${raw.size}).",
            )
        }
        return l2Normalize(raw)
    }

    private fun l2Normalize(v: FloatArray): FloatArray {
        var sumSq = 0.0
        for (x in v) sumSq += x.toDouble() * x
        val norm = kotlin.math.sqrt(sumSq)
        if (norm == 0.0) return v
        return FloatArray(v.size) { i -> (v[i] / norm).toFloat() }
    }

    override fun close() {
        interpreter?.close()
        interpreter = null
    }
}

/**
 * Used whenever [FaceBiometricConfig.embeddingModelAssetPath] is not
 * configured. Every method either reports unavailability or throws --
 * this class must never return a real-looking embedding. This is what
 * makes detection/tracking/liveness demoable with zero AI models while
 * guaranteeing recognition/authenticate() fail closed instead of
 * silently "working" with fake vectors (see README §13/§54 policy).
 */
class UnavailableFaceEmbeddingEngine(
    override val modelVersion: String = "none",
    override val embeddingDimension: Int = 0,
) : FaceEmbeddingEngine {
    override val isAvailable: Boolean = false

    override fun generateEmbedding(alignedTensor: FloatArray): FloatArray {
        throw BiometricException(
            FaceBiometricErrorCode.modelUnavailable,
            "No embedding model configured. Face recognition, enroll(), " +
                "authenticate(), and compare() are unavailable until " +
                "FaceBiometricConfig.embeddingModelAssetPath is set. " +
                "Detection, tracking, quality, and active liveness still work.",
        )
    }

    override fun close() {}
}

