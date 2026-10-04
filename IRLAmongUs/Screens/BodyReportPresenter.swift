import SwiftUI
import UIKit

/// A transparent scene window puts the banner over the HUD, maps and scanners.
struct BodyReportPresenter: UIViewRepresentable {
    let presentation: BodyReportPresentation?
    let dismiss: (UUID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> KillAnimationPresenter.AnchorView {
        let anchor = KillAnimationPresenter.AnchorView()
        anchor.isUserInteractionEnabled = false
        anchor.didAttach = { [weak coordinator = context.coordinator] in coordinator?.update(anchor: $0) }
        return anchor
    }
    func updateUIView(_ anchor: KillAnimationPresenter.AnchorView, context: Context) {
        context.coordinator.presentation = presentation
        context.coordinator.dismiss = dismiss
        context.coordinator.update(anchor: anchor)
    }
    static func dismantleUIView(_ anchor: KillAnimationPresenter.AnchorView, coordinator: Coordinator) {
        anchor.didAttach = nil
        coordinator.close()
    }

    @MainActor
    final class Coordinator {
        var presentation: BodyReportPresentation?
        var dismiss: ((UUID) -> Void)?
        private(set) var overlayWindow: UIWindow?
        private var presentationID: UUID?

        func update(anchor: UIView) {
            guard let presentation else { close(); return }
            guard let scene = anchor.window?.windowScene, presentationID != presentation.id else { return }
            close()
            // Freeze the current HUD/scanner before rotating the scene. A portrait
            // scanner must not turn sideways underneath a landscape banner.
            let backdrop = scene.windows.first(where: \.isKeyWindow).map { window in
                UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
            }
            // Preserve the current landscape side, or choose left from a portrait scanner.
            // Both windows must agree during the orientation transition.
            let orientation: UIInterfaceOrientationMask = scene.interfaceOrientation == .landscapeRight
                ? .landscapeRight : .landscapeLeft
            OrientationDelegate.requestOrientation(orientation)
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 2
            window.backgroundColor = .clear
            let controller = ReportController(rootView: BodyReportView(presentation: presentation, backdrop: backdrop) { [weak self] in
                self?.dismiss?(presentation.id)
            })
            controller.orientation = orientation
            controller.view.backgroundColor = .clear
            window.rootViewController = controller
            overlayWindow = window
            presentationID = presentation.id
            window.isHidden = false
        }

        func close() {
            overlayWindow?.isHidden = true
            overlayWindow?.rootViewController = nil
            overlayWindow = nil
            presentationID = nil
        }
    }

    private final class ReportController: UIHostingController<BodyReportView> {
        var orientation: UIInterfaceOrientationMask = .landscapeLeft
        override var supportedInterfaceOrientations: UIInterfaceOrientationMask { orientation }
        override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
            orientation == .landscapeRight ? .landscapeRight : .landscapeLeft
        }
    }
}
