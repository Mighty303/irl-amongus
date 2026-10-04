import AVFoundation
import SwiftUI
import UIKit

/// Live camera feed that reports QR codes and hands sampled frames to a callback (for sign recognition).
/// Callbacks for frames run on a background queue; QR callbacks run on the main queue.
struct CameraView: UIViewControllerRepresentable {
    var onQRCode: ((String) -> Void)? = nil
    var onFrame: ((CVPixelBuffer) -> Void)? = nil
    var frameInterval: TimeInterval = 0.4

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.frameInterval = frameInterval
        vc.onQRCode = onQRCode
        vc.onFrame = onFrame
        return vc
    }

    func updateUIViewController(_ vc: CameraViewController, context: Context) {
        vc.onQRCode = onQRCode
        vc.onFrame = onFrame
    }
}

final class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onQRCode: ((String) -> Void)?
    var onFrame: ((CVPixelBuffer) -> Void)?
    var frameInterval: TimeInterval = 0.4

    private let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "camera.frames")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    /// Tracks how the phone is physically held, so the preview and captured frames stay upright in
    /// portrait and landscape alike (sign photos were saved sideways when taken from the landscape lobby).
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservations: [NSKeyValueObservation] = []
    private var lastFrameAt = Date.distantPast
    private var lastQR: (String, Date)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { granted ? self.configure() : self.showMessage("Camera access denied.\nEnable it in Settings > IRL Among Us.") }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showMessage("No camera available (simulator?)")
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        if session.canAddInput(input) { session.addInput(input) }

        let metadata = AVCaptureMetadataOutput()
        if session.canAddOutput(metadata) {
            session.addOutput(metadata)
            metadata.setMetadataObjectsDelegate(self, queue: .main)
            metadata.metadataObjectTypes = [.qr]
        }

        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        video.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(video) {
            session.addOutput(video)
            videoOutput = video
        }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        rotationCoordinator = coordinator
        applyRotation()
        rotationObservations = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview) { [weak self] _, _ in
                DispatchQueue.main.async { self?.applyRotation() }
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture) { [weak self] _, _ in
                DispatchQueue.main.async { self?.applyRotation() }
            },
        ]
        CameraHandoff.start { self.session.startRunning() }
    }

    /// Keeps the preview level with the horizon and delivers frames (and so sign photos) upright.
    private func applyRotation() {
        guard let coordinator = rotationCoordinator else { return }
        let previewAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        if let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(previewAngle) {
            connection.videoRotationAngle = previewAngle
        }
        let captureAngle = coordinator.videoRotationAngleForHorizonLevelCapture
        if let connection = videoOutput?.connection(with: .video), connection.isVideoRotationAngleSupported(captureAngle) {
            connection.videoRotationAngle = captureAngle
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CameraUsage.backCameraStarted()
        // Tabs keep the controller alive; restart the session when it comes back on screen.
        if previewLayer != nil { CameraHandoff.start { if !self.session.isRunning { self.session.startRunning() } } }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CameraUsage.backCameraStopped()
        CameraHandoff.stop { self.session.stopRunning() }
    }

    private func showMessage(_ text: String) {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.frame = view.bounds.insetBy(dx: 20, dy: 20)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(label)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let value = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        // Debounce: the same code is reported every frame while it's in view.
        if let (last, at) = lastQR, last == value, Date().timeIntervalSince(at) < 2 { return }
        lastQR = (value, Date())
        onQRCode?(value)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let onFrame, Date().timeIntervalSince(lastFrameAt) >= frameInterval,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrameAt = Date()
        onFrame(buffer)
    }
}

extension CVPixelBuffer {
    func toUIImage() -> UIImage? {
        let ci = CIImage(cvPixelBuffer: self)
        guard let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
