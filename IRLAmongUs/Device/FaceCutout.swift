import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit
import Vision

/// Turns a photo into a cut-out head for the player's crewmate, entirely on the phone.
enum FaceCutout {
    /// The photo upright and at most `maxDimension` px, so cropping and segmentation see what the user sees.
    static func prepare(_ image: UIImage, maxDimension: CGFloat = 1200) -> UIImage {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// The photo with everything except the person made transparent (Vision person segmentation).
    /// Nil when no person is found or segmentation isn't available (e.g. the Simulator).
    static func removeBackground(_ image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let result = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: .up).perform([request])
            } catch {
                return nil
            }
            guard let mask = request.results?.first?.pixelBuffer else { return nil }
            let photo = CIImage(cgImage: cgImage)
            var maskImage = CIImage(cvPixelBuffer: mask)
            maskImage = maskImage.transformed(by: CGAffineTransform(
                scaleX: photo.extent.width / maskImage.extent.width,
                y: photo.extent.height / maskImage.extent.height))
            let blend = CIFilter.blendWithMask()
            blend.inputImage = photo
            blend.backgroundImage = CIImage.empty()
            blend.maskImage = maskImage
            guard let output = blend.outputImage else { return nil }
            return CIContext().createCGImage(output, from: photo.extent)
        }.value
        return result.map { UIImage(cgImage: $0) }
    }

    /// Renders the fitted oval as the transparent PNG that goes on everyone's screen.
    @MainActor
    static func headPNG(_ image: UIImage, zoom: CGFloat, offset: CGSize) -> Data? {
        let renderer = ImageRenderer(content: FaceCrop(image: image, zoom: zoom, offset: offset)
            .frame(width: FaceCrop.exportSize.width, height: FaceCrop.exportSize.height))
        renderer.isOpaque = false
        renderer.scale = 1
        return renderer.uiImage?.pngData()
    }
}

/// The user's photo framed in the head oval. Zoom and offset are relative to the oval's width,
/// so the fitting screen, the live preview and the exported PNG all show the same crop.
struct FaceCrop: View {
    /// Width : height of the head oval.
    static let aspect: CGFloat = 0.8
    static let exportSize = CGSize(width: 280, height: 350)

    let image: UIImage
    let zoom: CGFloat
    let offset: CGSize

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoom)
                .offset(x: offset.width * geo.size.width, y: offset.height * geo.size.width)
        }
        .clipShape(Ellipse())
    }
}

/// The front camera, for taking a selfie to put on your crewmate.
struct SelfieCamera: UIViewControllerRepresentable {
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if UIImagePickerController.isCameraDeviceAvailable(.front) { picker.cameraDevice = .front }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SelfieCamera
        init(_ parent: SelfieCamera) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPhoto(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
