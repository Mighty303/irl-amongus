import SwiftUI
import UIKit

@main
struct IRLAmongUsApp: App {
    @UIApplicationDelegateAdaptor(OrientationDelegate.self) private var orientationDelegate
    @State private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .background {
                    KillAnimationPresenter(presentation: store.killPresentation) { store.dismissKill($0) }
                        .frame(width: 0, height: 0)
                }
                .onOpenURL { url in Task { await store.handle(url: url) } }
                .onChange(of: scenePhase) { _, phase in store.scenePhaseChanged(phase) }
                .onChange(of: store.session) { _, session in
                    // Phones stay face-up and awake during play (bodies especially).
                    UIApplication.shared.isIdleTimerDisabled = session != nil
                }
        }
    }
}

@MainActor
final class OrientationDelegate: NSObject, UIApplicationDelegate {
    static var supportedOrientations: UIInterfaceOrientationMask = .landscape

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.supportedOrientations
    }

    static func requestLandscape() { requestOrientation(.landscape) }
    static func requestPortrait() { requestOrientation(.portrait) }

    private static func requestOrientation(_ mask: UIInterfaceOrientationMask) {
        supportedOrientations = mask
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            guard scene.activationState == .foregroundActive else { continue }
            for window in scene.windows {
                var controller = window.rootViewController
                while let current = controller {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    controller = current.presentedViewController
                }
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: supportedOrientations))
        }
    }
}
