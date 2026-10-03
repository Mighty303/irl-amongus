import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeImage: View {
    let payload: String
    var size: CGFloat = 200

    var body: some View {
        if let image = Self.make(payload) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Text("QR failed")
        }
    }

    static func make(_ string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
