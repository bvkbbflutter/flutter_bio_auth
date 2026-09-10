package com.vinay.flutter_bio_auth

import android.content.Context
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.platform.PlatformView

/**
 * Native camera preview surface exposed to Flutter via
 * `AndroidView(viewType: "flutter_bio_auth/camera_preview")`.
 * Flutter draws its own UI (challenge instructions, progress dots,
 * etc.) as an overlay on top of this; this view only ever shows the
 * live camera feed.
 */
class FaceBiometricView(
    context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val mirror: Boolean,
) : PlatformView {

    private val previewView: PreviewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
        // In CameraX, PreviewView automatically mirrors LENS_FACING_FRONT so it behaves
        // like a natural selfie mirror. Setting scaleX = -1f inverted it horizontally.
        // When mirror is true, maintain natural 1f; only flip if caller explicitly disabled mirror.
        scaleX = if (mirror) 1f else -1f
    }

    var onDispose: (() -> Unit)? = null

    fun attachCameraManager(cameraManager: CameraManager) {
        val p = cameraManager.preview
        if (p != null) {
            val rot = previewView.display?.rotation
            if (rot != null) {
                try { p.targetRotation = rot } catch (_: Exception) {}
            }
            p.setSurfaceProvider(previewView.surfaceProvider)
        } else {
            cameraManager.onPreviewConfigured = { previewUseCase ->
                previewView.post {
                    val rot = previewView.display?.rotation
                    if (rot != null) {
                        try { previewUseCase.targetRotation = rot } catch (_: Exception) {}
                    }
                    previewUseCase.setSurfaceProvider(previewView.surfaceProvider)
                }
            }
        }
    }

    override fun getView() = previewView

    override fun dispose() {
        onDispose?.invoke()
    }
}
