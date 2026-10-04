import ARKit
import CoreImage
import SceneKit
import UIKit

/// Renders the captured image and world camera using the SAME window orientation.
/// ARSCNView's automatic background rotation can disagree with a locked SwiftUI host.
@MainActor
final class WalkingSceneView: SCNView {
    let session = ARSession()
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private let cameraNode = SCNNode()
    private var lastImageTime: TimeInterval = 0

    func prepareScene() {
        let scene = SCNScene()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        self.scene = scene
        pointOfView = cameraNode
        autoenablesDefaultLighting = true
        preferredFramesPerSecond = 30
        isPlaying = true
    }

    func present(_ frame: ARFrame) {
        guard let window, bounds.width > 0, bounds.height > 0,
              let orientation = window.windowScene?.interfaceOrientation,
              orientation == .landscapeLeft || orientation == .landscapeRight else { return }
        let viewport = bounds.size
        // Keep virtual beacons and the preview in exactly the same orientation and aspect fill.
        cameraNode.simdTransform = simd_inverse(frame.camera.viewMatrix(for: orientation))
        cameraNode.camera?.projectionTransform = SCNMatrix4(frame.camera.projectionMatrix(
            for: orientation, viewportSize: viewport, zNear: 0.01, zFar: 100))
        guard frame.timestamp - lastImageTime >= 1.0 / 30 else { return }
        lastImageTime = frame.timestamp
        let input = CIImage(cvPixelBuffer: frame.capturedImage)
        // Limit raster cost without changing the field of view; AR tracking keeps its native frames.
        let scale = min(window.screen.scale, 1280 / max(viewport.width, viewport.height))
        let outputSize = CGSize(width: (viewport.width * scale).rounded(), height: (viewport.height * scale).rounded())
        let display = frame.displayTransform(for: orientation, viewportSize: viewport)
        let transform = Self.imageTransform(imageSize: input.extent.size,
                                            viewportSize: outputSize, displayTransform: display)
        let image = input.transformed(by: transform)
        let outputRect = CGRect(origin: .zero, size: outputSize)
        guard let rendered = imageContext.createCGImage(image, from: outputRect) else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        scene?.background.contents = rendered
        SCNTransaction.commit()
    }

    /// ARKit uses normalized top-left coordinates; Core Image uses pixel bottom-left coordinates.
    static func imageTransform(imageSize: CGSize, viewportSize: CGSize,
                               displayTransform: CGAffineTransform) -> CGAffineTransform {
        CGAffineTransform(a: 1 / imageSize.width, b: 0, c: 0, d: -1 / imageSize.height, tx: 0, ty: 1)
            .concatenating(displayTransform)
            .concatenating(CGAffineTransform(a: viewportSize.width, b: 0, c: 0,
                                            d: -viewportSize.height, tx: 0, ty: viewportSize.height))
    }
}
