import AVFoundation
import UIKit

/// Whether the back camera is on screen (scanning a sign, photographing one). A phone can't run both
/// cameras at once, so the security-camera stream pauses while it is.
enum CameraUsage {
    static let changed = Notification.Name("CameraUsageChanged")
    private(set) static var backCameraViews = 0 { didSet { NotificationCenter.default.post(name: changed, object: nil) } }
    static var backCameraInUse: Bool { backCameraViews > 0 }

    static func backCameraStarted() { DispatchQueue.main.async { backCameraViews += 1 } }
    static func backCameraStopped() { DispatchQueue.main.async { backCameraViews = max(0, backCameraViews - 1) } }
}

/// The front camera as a security camera: small upright JPEG frames a few times a second, only while
/// someone is watching (the server says so). Kept tiny (~240 px) so many phones fit through one server.
final class FrontCameraStreamer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private(set) var isRunning = false
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "front-camera")
    private var configured = false
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var output: AVCaptureVideoDataOutput?
    private var lastFrameAt = Date.distantPast
    private let context = CIContext()
    private var onFrame: ((String) -> Void)?

    private static let interval: TimeInterval = 0.3
    private static let maxDimension: CGFloat = 240

    /// Starts sending frames to `onFrame` (base64 JPEG), on a background queue.
    func start(onFrame: @escaping (String) -> Void) {
        self.onFrame = onFrame
        guard !isRunning else { return }
        isRunning = true
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.queue.async {
                if !self.configured { self.configure() }
                if self.isRunning, !self.session.isRunning { self.session.startRunning() }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        onFrame = nil
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.sessionPreset = .low
        if session.canAddInput(input) { session.addInput(input) }
        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        video.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(video) { session.addOutput(video) }
        output = video
        session.commitConfiguration()
        // Frames upright however the phone is held.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotation = coordinator
        if let connection = video.connection(with: .video) {
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        }
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRunning, let onFrame, Date().timeIntervalSince(lastFrameAt) >= Self.interval,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrameAt = Date()
        if let rotation, connection.isVideoRotationAngleSupported(rotation.videoRotationAngleForHorizonLevelCapture) {
            connection.videoRotationAngle = rotation.videoRotationAngleForHorizonLevelCapture
        }
        var image = CIImage(cvPixelBuffer: buffer)
        let scale = min(1, Self.maxDimension / max(image.extent.width, image.extent.height))
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(image, from: image.extent),
              let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.45) else { return }
        onFrame(jpeg.base64EncodedString())
    }
}
