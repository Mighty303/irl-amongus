import Foundation
import Observation
import UIKit

/// Shared across sprite views so short animations can use heads already fetched from the roster.
@MainActor @Observable
final class PlayerFaceCache {
    static let shared = PlayerFaceCache()
    private(set) var images: [URL: UIImage] = [:]
    @ObservationIgnored private let httpSession: URLSession

    init(httpSession: URLSession = .shared) { self.httpSession = httpSession }

    @ObservationIgnored private var requests: [URL: Task<UIImage?, Never>] = [:]

    func load(_ url: URL?) async {
        guard let url, images[url] == nil else { return }
        let request: Task<UIImage?, Never>
        if let pending = requests[url] {
            request = pending
        } else {
            request = Task {
                guard let (data, response) = try? await httpSession.data(from: url),
                      let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return nil }
                return UIImage(data: data)
            }
            requests[url] = request
        }
        if let image = await request.value {
            if images.count >= 128, let key = images.keys.first { images.removeValue(forKey: key) }
            images[url] = image
        }
        requests[url] = nil
    }

    func prefetch(_ urls: [URL]) {
        for url in Set(urls) where images[url] == nil && requests[url] == nil {
            Task { await load(url) }
        }
    }
}
