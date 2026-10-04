import Foundation
import simd

struct ARMapTask: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var x: Float
    var y: Float
    var point: SIMD2<Float> { SIMD2(x, y) }
}

/// A measured 12 x 12 metre area. Origin is on the floor below the wall marker.
/// +x is right when facing the upright marker; +y extends away from its wall.
struct ARMapLayout: Codable, Equatable {
    var markerWidthM: Float = 0.2
    var markerCentreHeightM: Float = 1.2
    var tasks: [ARMapTask] = [
        ARMapTask(id: "electrical", name: "Electrical", x: 0, y: 3),
        ARMapTask(id: "reactor", name: "Reactor", x: -3, y: 6),
        ARMapTask(id: "medbay", name: "Medbay", x: 3, y: 8)
    ]

    var isValid: Bool {
        markerWidthM.isFinite && (0.05...0.4).contains(markerWidthM)
        && markerCentreHeightM.isFinite && (0.2...2.5).contains(markerCentreHeightM)
        && tasks.count == 3 && Set(tasks.map(\.id)).count == tasks.count
        && tasks.allSatisfy {
            !$0.id.isEmpty && !$0.name.isEmpty && $0.x.isFinite && $0.y.isFinite
            && (-6...6).contains($0.x) && (0...12).contains($0.y)
        }
    }

    static let storageKey = "arWalking.measuredMap.v1"

    static func load(from defaults: UserDefaults = .standard) -> ARMapLayout {
        guard let data = defaults.data(forKey: storageKey),
              let layout = try? JSONDecoder().decode(Self.self, from: data), layout.isValid else { return Self() }
        return layout
    }

    func save(to defaults: UserDefaults = .standard) {
        guard isValid, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// Gravity-aligned transform from the measured map into AR world coordinates.
/// Only upright wall markers are accepted. The marker's x axis defines map-right.
struct ARMapAlignment {
    let floorOrigin: SIMD3<Float>
    let right: SIMD3<Float>
    let awayFromWall: SIMD3<Float>

    init?(markerTransform: simd_float4x4, centreHeight: Float) {
        guard centreHeight.isFinite, (0.2...2.5).contains(centreHeight),
              (0..<4).allSatisfy({ column in
                  (0..<4).allSatisfy { markerTransform[column][$0].isFinite }
              }) else { return nil }
        let axis = markerTransform.columns.0
        let normal = markerTransform.columns.1
        // AR image anchors lie in their local x-z plane, with y normal to the image.
        guard abs(axis.y) < 0.25, abs(normal.y) < 0.25 else { return nil }
        let horizontal = SIMD3(axis.x, 0, axis.z)
        guard simd_length(horizontal) > 0.9 else { return nil }
        right = simd_normalize(horizontal)
        awayFromWall = simd_cross(right, SIMD3(0, 1, 0))
        let centre = markerTransform.columns.3
        floorOrigin = SIMD3(centre.x, centre.y - centreHeight, centre.z)
    }

    func worldPoint(_ mapPoint: SIMD2<Float>, height: Float = 0) -> SIMD3<Float> {
        floorOrigin + right * mapPoint.x + awayFromWall * mapPoint.y + SIMD3(0, height, 0)
    }

    func mapPoint(_ worldPoint: SIMD3<Float>) -> SIMD2<Float> {
        let offset = worldPoint - floorOrigin
        return SIMD2(simd_dot(offset, right), simd_dot(offset, awayFromWall))
    }
}
