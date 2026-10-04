import SwiftUI

/// SFU Companion's mobile room palette and ordered room-type categories.
/// Adapted from RoomFinderScreen.tsx at b458870; see MAP_DATA_ATTRIBUTION.md.
enum RoomMapCategory: CaseIterable {
    case corridor, general, teaching, amenity, washroom

    init(roomType: String) {
        let type = roomType.lowercased()
        if type.contains("corridor") { self = .corridor }
        else if type.contains("washroom") { self = .washroom }
        // Lecture Theatre must match teaching before the amenity theatre rule.
        else if ["classroom", "lecture", "seminar"].contains(where: type.contains) { self = .teaching }
        else if (type.contains("lounge") && !type.contains("staff")) || Self.amenityTypes.contains(where: type.contains) {
            self = .amenity
        } else { self = .general }
    }

    private static let amenityTypes = [
        "cafeteria", "dining", "concession", "librar", "study area", "student club", "public seating",
        "lobby", "foyer", "bookstore", "retail", "gymnasium", "court", "swimming", "dance studio",
        "gallery", "theatre", "clinic", "first aid", "physiotherapy", "place of worship"
    ]

    var rgb: UInt32 {
        switch self {
        case .corridor: 0x141c22
        case .general: 0x46606f
        case .teaching: 0x7cc4ff
        case .amenity: 0xef7fae
        case .washroom: 0x35a97f
        }
    }

    var color: Color { Self.color(rgb) }
    var labelColor: Color {
        switch self {
        case .teaching, .amenity, .washroom: Self.color(0x0c1620)
        case .corridor, .general: Self.color(0xd9e3eb)
        }
    }

    static let selected = color(0xffe284)
    static func color(_ rgb: UInt32) -> Color {
        Color(red: Double((rgb >> 16) & 255) / 255,
              green: Double((rgb >> 8) & 255) / 255,
              blue: Double(rgb & 255) / 255)
    }
}

extension POCRoom {
    var mapCategory: RoomMapCategory { RoomMapCategory(roomType: roomType) }
    var mapFill: Color { mapCategory.color.opacity(0.9) }
}
