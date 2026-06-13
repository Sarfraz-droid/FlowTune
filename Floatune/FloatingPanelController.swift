import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    static let shared = FloatingPanelController()

    private var panel: PlayerPanel?
    private var cancellables = Set<AnyCancellable>()

    func configure(with model: AppModel) {
        guard panel == nil else { return }

        let initialSize = size(expanded: model.isExpanded)
        let panel = PlayerPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: FloatingPlayerView().environmentObject(model))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The system panel shadow follows the transparent rectangular window
        // bounds, creating a dark selection outline around the glass card.
        panel.hasShadow = false
        panel.level = model.settings.alwaysOnTop ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.setFrameAutosaveName("FloatuneFloatingPlayer")
        if panel.setFrameUsingName("FloatuneFloatingPlayer") == false {
            positionAtTopRight(panel)
        }
        self.panel = panel

        model.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in self?.resize(expanded: expanded) }
            .store(in: &cancellables)

        model.settings.$alwaysOnTop
            .removeDuplicates()
            .sink { [weak panel] enabled in panel?.level = enabled ? .floating : .normal }
            .store(in: &cancellables)

        model.settings.$showFloatingPlayer
            .removeDuplicates()
            .sink { [weak self] visible in
                visible ? self?.show() : self?.hide()
            }
            .store(in: &cancellables)
    }

    func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            AppSettings.shared.showFloatingPlayer = false
        } else {
            AppSettings.shared.showFloatingPlayer = true
            show()
        }
    }

    func show() {
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        AppSettings.shared.showFloatingPlayer = false
        return false
    }

    private func resize(expanded: Bool) {
        guard let panel else { return }
        var frame = panel.frame
        let newSize = size(expanded: expanded)
        frame.origin.y += frame.height - newSize.height
        frame.size = newSize

        guard NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == false else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func size(expanded: Bool) -> NSSize {
        NSSize(width: 420, height: expanded ? 292 : 92)
    }

    private func positionAtTopRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        let frame = panel.frame
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - frame.width - 24,
            y: visible.maxY - frame.height - 24
        ))
    }
}

private final class PlayerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
