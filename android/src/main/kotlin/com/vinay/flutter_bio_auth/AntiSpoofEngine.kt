package com.vinay.flutter_bio_auth

import android.content.res.AssetManager
import com.vinay.flutter_bio_auth.model.AntiSpoofReason
import com.vinay.flutter_bio_auth.model.AntiSpoofResult
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

/**
 * Passive presentation-attack signal from a single aligned face
 * tensor. Explicitly separate from [FaceTracker]'s active-liveness
 * gesture detectors -- see README "Liveness security": a blink/turn
 * challenge is not passive anti-spoofing.
 */
interface AntiSpoofEngine {
    val isAvailable: Boolean
    fun analyze(alignedTensor: FloatArray): AntiSpoofResult
    fun close()
}

/**
 * Loads a binary live-vs-spoof classifier from a developer-supplied
 * asset path, analogous to [TFLiteFaceEmbeddingEngine]. Expected
 * output: a single float in [0,1], the probability the input is a
 * live capture (index 0 = spoof, index 1 = live, or a single sigmoid
 * output -- adjust the postprocessing below to match whatever model
 * you bundle; the default assumes a single sigmoid output).
 */
class TFLiteAntiSpoofEngine(
    assetManager: AssetManager,
    flutterAssetPath: String?,
) : AntiSpoofEngine {

    private var interpreter: Interpreter? = null

    override val isAvailable: Boolean
        get() = interpreter != null

    init {
        if (!flutterAssetPath.isNullOrBlank()) {
            try {
                val buffer: ByteBuffer = try {
                    val fd = assetManager.openFd(flutterAssetPath)
                    java.io.FileInputStream(fd.fileDescriptor).use { input ->
                        input.channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
                    }
                } catch (e: Exception) {
                    assetManager.open(flutterAssetPath).use { input ->
                        val bytes = input.readBytes()
                        val direct = ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder())
                        direct.put(bytes)
                        direct.rewind()
                        direct
                    }
                }
                interpreter = Interpreter(buffer)
            } catch (e: Exception) {
                interpreter = null
            }
        }
    }

    override fun analyze(alignedTensor: FloatArray): AntiSpoofResult {
        val engine = interpreter ?: return AntiSpoofResult.UNAVAILABLE

        val inputBuffer = ByteBuffer.allocateDirect(alignedTensor.size * 4).order(ByteOrder.nativeOrder())
        inputBuffer.asFloatBuffer().put(alignedTensor)
        inputBuffer.rewind()
        val output = Array(1) { FloatArray(1) }

        return try {
            engine.run(inputBuffer, output)
            val liveProbability = output[0][0].toDouble().coerceIn(0.0, 1.0)
            AntiSpoofResult(
                isLive = liveProbability >= 0.5,
                confidence = liveProbability,
                reason = if (liveProbability >= 0.5) AntiSpoofReason.live else AntiSpoofReason.suspiciousTexture,
            )
        } catch (e: Exception) {
            AntiSpoofResult(isLive = false, confidence = 0.0, reason = AntiSpoofReason.unknown)
        }
    }

    override fun close() {
        interpreter?.close()
        interpreter = null
    }
}

/** Used when [FaceBiometricConfig.antiSpoofModelAssetPath] is unset.
 *  Always reports [AntiSpoofResult.UNAVAILABLE] -- never a pass -- so
 *  callers requiring anti-spoofing fail closed rather than silently
 *  downgrading security. */
class UnavailableAntiSpoofEngine : AntiSpoofEngine {
    override val isAvailable: Boolean = false
    override fun analyze(alignedTensor: FloatArray): AntiSpoofResult = AntiSpoofResult.UNAVAILABLE
    override fun close() {}
}
