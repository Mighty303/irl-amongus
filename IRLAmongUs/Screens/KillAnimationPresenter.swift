import SwiftUI
import UIKit

/// A separate scene window keeps the death cue above maps, scanners and sheets.
/// It doesn't become the key window, so the underlying screen keeps its session.
struct KillAnimationPresenter: UIViewRepresentable {
    let presentation: KillPresentation?
    let dismiss: (UUID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> AnchorView {
        let anchor = AnchorView()
        anchor.isUserInteractionEnabled = false
        anchor.didAttach = { [weak coordinator = context.coordinator] anchor in
            coordinator?.update(anchor: anchor)
        }
        return anchor
    }

    func updateUIView(_ anchor: AnchorView, context: Context) {
        context.coordinator.presentation = presentation
        context.coordinator.dismiss = dismiss
        context.coordinator.update(anchor: anchor)
    }

    static func dismantleUIView(_ anchor: AnchorView, coordinator: Coordinator) {
        anchor.didAttach = nil
        coordinator.close()
    }

    final class AnchorView: UIView {
        var didAttach: ((AnchorView) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            didAttach?(self)
        }
    }

    @MainActor
    final class Coordinator {
        var presentation: KillPresentation?
        var dismiss: ((UUID) -> Void)?
        private(set) var overlayWindow: UIWindow?
        private var presentationID: UUID?

        func update(anchor: UIView) {
            guard let presentation else { close(); return }
            guard let scene = anchor.window?.windowScene else { return }

            let view = KillAnimationView(presentation: presentation) { [weak self] in
                self?.dismiss?(presentation.id)
            }
            if presentationID == presentation.id,
               let controller = overlayWindow?.rootViewController as? UIHostingController<KillAnimationView> {
                // A later event can fill in the attacker's colour without restarting playback.
                controller.rootView = view
                return
            }

            close()
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.backgroundColor = .black
            window.rootViewController = UIHostingController(rootView: view)
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
}
