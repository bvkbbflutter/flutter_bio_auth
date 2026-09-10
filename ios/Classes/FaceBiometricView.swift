import Flutter
import UIKit
import AVFoundation

final class FaceBiometricPreviewContainer: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

/// Native camera preview exposed to Flutter via
/// `UiKitView(viewType: "flutter_bio_auth/camera_preview")`.
/// Flutter draws its own UI (instructions, progress dots) as an
/// overlay on top; this view only ever shows the live camera feed.
final class FaceBiometricView: NSObject, FlutterPlatformView {
    private let containerView: FaceBiometricPreviewContainer
    private var onDispose: (() -> Void)?

    init(frame: CGRect, mirror: Bool, onDispose: (() -> Void)? = nil) {
        self.containerView = FaceBiometricPreviewContainer(frame: frame)
        self.containerView.backgroundColor = .black
        self.onDispose = onDispose
        if mirror {
            self.containerView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
        super.init()
    }

    func attach(cameraManager: CameraManager) {
        let layer = cameraManager.previewLayer
        layer.videoGravity = .resizeAspectFill
        layer.frame = containerView.bounds
        containerView.previewLayer = layer
        if layer.superlayer !== containerView.layer {
            layer.removeFromSuperlayer()
            containerView.layer.addSublayer(layer)
        }
    }

    func view() -> UIView { containerView }

    deinit {
        onDispose?()
    }
}

final class FaceBiometricViewFactory: NSObject, FlutterPlatformViewFactory {
    private let cameraManagerProvider: () -> CameraManager?
    private let mirrorProvider: () -> Bool
    private let onViewCreated: (FaceBiometricView) -> Void
    private let onViewDisposed: () -> Void

    init(
        cameraManagerProvider: @escaping () -> CameraManager?,
        mirrorProvider: @escaping () -> Bool,
        onViewCreated: @escaping (FaceBiometricView) -> Void,
        onViewDisposed: @escaping () -> Void
    ) {
        self.cameraManagerProvider = cameraManagerProvider
        self.mirrorProvider = mirrorProvider
        self.onViewCreated = onViewCreated
        self.onViewDisposed = onViewDisposed
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let view = FaceBiometricView(frame: frame, mirror: mirrorProvider(), onDispose: onViewDisposed)
        onViewCreated(view)
        if let manager = cameraManagerProvider() {
            view.attach(cameraManager: manager)
        }
        return view
    }
}
