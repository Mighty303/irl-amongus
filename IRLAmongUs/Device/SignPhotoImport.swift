import CoreLocation
import ImageIO
import PhotosUI
import SwiftUI

/// A sign photo picked from the photo library, with the GPS location saved in its metadata (if any).
/// The system picker hands over the original image data without asking for photo library access.
struct ImportedSignPhoto {
    let image: UIImage
    let coordinate: CLLocationCoordinate2D?
}

enum SignPhotoImport {
    static func load(_ item: PhotosPickerItem) async -> ImportedSignPhoto? {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return nil }
        return ImportedSignPhoto(image: image.upright(), coordinate: coordinate(in: data))
    }

    /// Reads the EXIF GPS block. iPhone camera photos have one when Location Services was on for the Camera.
    static func coordinate(in data: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              var latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              var longitude = gps[kCGImagePropertyGPSLongitude] as? Double else { return nil }
        if gps[kCGImagePropertyGPSLatitudeRef] as? String == "S" { latitude = -latitude }
        if gps[kCGImagePropertyGPSLongitudeRef] as? String == "W" { longitude = -longitude }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }
}

extension UIImage {
    /// Pixels redrawn upright, so Vision (which reads raw pixels) sees the sign the right way up.
    func upright() -> UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
