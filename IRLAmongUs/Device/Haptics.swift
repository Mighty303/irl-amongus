import AudioToolbox
import UIKit

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    /// Subtle buzz for the impostor when someone enters kill range. Should be unnoticeable to others.
    static func killInRange() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }

    /// Unmissable alarm: body reported, emergency meeting, sabotage.
    static func alarm(times: Int = 3) {
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
}
