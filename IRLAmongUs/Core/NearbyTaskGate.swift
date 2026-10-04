import Foundation
import simd

/// Local POC interaction rules, in metres in an AR session's horizontal coordinate space.
/// This does not authorize online tasks or assert an absolute indoor location.
struct NearbyTaskGate {
    static let interactionRadius: Float = 2
    static let revealRadius: Float = 4
    static let hideRadius: Float = 5
    static let stopSpeed: Float = 0.35
    static let dwellSeconds = 0.5

    private(set) var task: SIMD2<Float>?
    private(set) var position: SIMD2<Float>?
    private(set) var distance: Float?
    private(set) var speed: Float?
    private(set) var nearby = false
    private(set) var ready = false
    private(set) var passedAt: Double?
    private var previous: (point: SIMD2<Float>, time: Double)?
    private var stoppedSince: Double?

    mutating func placeTask(_ point: SIMD2<Float>) {
        self = NearbyTaskGate()
        task = point
    }

    /// Freeze the last map position and require a fresh continuous dwell after recovery.
    mutating func pause() {
        previous = nil
        stoppedSince = nil
        speed = nil
        ready = false
        passedAt = nil
    }

    mutating func update(position point: SIMD2<Float>, at time: Double, tracking: Bool) {
        guard tracking, point.x.isFinite, point.y.isFinite, time.isFinite else {
            pause()
            return
        }
        guard let task else { return }
        let old = previous
        position = point
        distance = simd_distance(point, task)
        nearby = distance! <= (nearby ? Self.hideRadius : Self.revealRadius)
        ready = false
        previous = (point, time)
        guard let old, time > old.time, time - old.time <= 0.35 else {
            speed = nil
            stoppedSince = nil
            return
        }
        speed = simd_distance(point, old.point) / Float(time - old.time)
        if Self.segmentDistance(task, from: old.point, to: point) <= Self.revealRadius {
            passedAt = time
        }
        guard distance! <= Self.interactionRadius, speed! <= Self.stopSpeed else {
            stoppedSince = nil
            return
        }
        if stoppedSince == nil { stoppedSince = time }
        ready = time - stoppedSince! >= Self.dwellSeconds
    }

    static func segmentDistance(_ point: SIMD2<Float>, from start: SIMD2<Float>, to end: SIMD2<Float>) -> Float {
        let delta = end - start
        let lengthSquared = simd_length_squared(delta)
        guard lengthSquared > 0 else { return simd_distance(point, start) }
        let fraction = min(1, max(0, simd_dot(point - start, delta) / lengthSquared))
        return simd_distance(point, start + delta * fraction)
    }
}
