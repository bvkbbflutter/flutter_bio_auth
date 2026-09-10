import AVFoundation
import UIKit

/// Owns the AVCaptureSession: front camera selection, frame
/// throttling (~12.5 FPS analysis cadence even though the sensor runs
/// faster), and correct sample-buffer handling so no buffers are
/// retained past their analysis window. Raw frames never leave this
/// class -- only FaceAnalyzer's structured output is handed upward.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let analysisQueue = DispatchQueue(label: "flutter_bio_auth.analysis")
    private let faceAnalyzer = FaceAnalyzer()

    private var processingFrame = false
    private var lastAnalysisTimestamp: TimeInterval = 0
    private let minAnalysisInterval: TimeInterval = 0.08 // ~12.5 FPS

    var onFrame: ((UIImage, FaceDetectionResult) -> Void)?
    var onError: ((BiometricException) -> Void)?

    var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func start(onReady: @escaping () -> Void, onFailure: @escaping (BiometricException) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                onFailure(BiometricException(.cameraPermissionDenied, "Camera permission not granted."))
                return
            }
            self.analysisQueue.async {
                do {
                    try self.configureSession()
                    self.session.startRunning()
                    DispatchQueue.main.async { onReady() }
                } catch let error as BiometricException {
                    DispatchQueue.main.async { onFailure(error) }
                } catch {
                    DispatchQueue.main.async {
                        onFailure(BiometricException(.cameraUnavailable, "Failed to start the camera.", underlying: error))
                    }
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            throw BiometricException(.cameraUnavailable, "No compatible front camera available.")
        }
        session.inputs.forEach { session.removeInput($0) }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: analysisQueue)
        guard session.canAddOutput(output) else {
            throw BiometricException(.cameraUnavailable, "Could not attach the video output.")
        }
        session.outputs.forEach { session.removeOutput($0) }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            connection.videoOrientation = .portrait
            if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastAnalysisTimestamp >= minAnalysisInterval, !processingFrame else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        processingFrame = true
        lastAnalysisTimestamp = now

        faceAnalyzer.analyze(pixelBuffer: pixelBuffer, orientation: .up) { [weak self] result in
            guard let self = self else { return }
            defer { self.processingFrame = false }
            if let image = self.imageFromPixelBuffer(pixelBuffer) {
                DispatchQueue.main.async { self.onFrame?(image, result) }
            }
        }
    }

    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Stops the session without releasing the analyzer; suitable for
    /// app-background/foreground transitions.
    func stop() {
        analysisQueue.async { [weak self] in self?.session.stopRunning() }
    }

    /// Full teardown.
    func dispose() {
        stop()
    }
}
