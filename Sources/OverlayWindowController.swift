// Floating Camera — MIT License. See LICENSE.

import AppKit
import AVFoundation

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    private let overlayView: OverlayView
    private let onOriginChanged: (CGPoint) -> Void
    private var settings: AppSettings

    var onContextMenu: (() -> NSMenu?)?

    var windowFrame: NSRect { window?.frame ?? .zero }
    var screen: NSScreen? { window?.screen ?? NSScreen.main }

    init(
        session: AVCaptureSession,
        settings: AppSettings,
        frame: NSRect,
        onOriginChanged: @escaping (CGPoint) -> Void
    ) {
        self.settings = settings
        self.onOriginChanged = onOriginChanged
        self.overlayView = OverlayView(session: session, settings: settings)

        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)

        panel.delegate = self
        panel.contentView = overlayView
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.level = settings.isAlwaysOnTop ? .floating : .normal
        panel.alphaValue = CGFloat(settings.opacity)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        overlayView.onContextMenu = { [weak self] in
            self?.onContextMenu?()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func setFrame(_ frame: NSRect) {
        window?.setFrame(frame, display: true)
        window?.invalidateShadow()
    }

    func apply(settings: AppSettings) {
        let previous = self.settings
        self.settings = settings

        overlayView.setMirror(settings.isMirrored)

        if previous.shape != settings.shape
            || previous.borderWidth != settings.borderWidth
            || previous.borderColor != settings.borderColor
            || previous.cornerRadius != settings.cornerRadius
            || previous.zoom != settings.zoom {
            overlayView.update(settings: settings)
            window?.invalidateShadow()
        }

        if previous.opacity != settings.opacity {
            window?.alphaValue = CGFloat(settings.opacity)
        }

        if previous.isAlwaysOnTop != settings.isAlwaysOnTop {
            window?.level = settings.isAlwaysOnTop ? .floating : .normal
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let origin = window?.frame.origin else { return }
        onOriginChanged(origin)
    }
}
