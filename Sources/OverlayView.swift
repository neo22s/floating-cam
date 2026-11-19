// Floating Camera — MIT License. See LICENSE.

import AppKit
import AVFoundation
import QuartzCore

final class OverlayView: NSView {
    private let cameraContainerLayer = CALayer()
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let maskLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let resizeBandLayer = CAShapeLayer()
    private var resizeHitPath: CGPath = CGMutablePath()
    private var settings: AppSettings
    private var resizeTrackingArea: NSTrackingArea?
    private var resizeDrag: (frame: NSRect, mouse: CGPoint, cursor: NSCursor)?

    var onContextMenu: (() -> NSMenu?)?
    var onResizeEnded: (() -> Void)?

    override var isOpaque: Bool { false }

    init(session: AVCaptureSession, settings: AppSettings) {
        self.settings = settings
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        cameraContainerLayer.allowsEdgeAntialiasing = true
        cameraContainerLayer.mask = maskLayer
        cameraContainerLayer.addSublayer(previewLayer)
        layer?.addSublayer(cameraContainerLayer)
        layer?.addSublayer(borderLayer)

        resizeBandLayer.fillColor = NSColor.clear.cgColor
        // Fully transparent pixels pass mouse events through to the window behind.
        resizeBandLayer.strokeColor = NSColor.black.withAlphaComponent(1.0 / 255).cgColor
        resizeBandLayer.lineWidth = OverlayGeometry.resizeBandWidth
        resizeBandLayer.lineJoin = .round
        layer?.addSublayer(resizeBandLayer)

        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.backgroundColor = NSColor.black.cgColor
        previewLayer.allowsEdgeAntialiasing = true

        maskLayer.fillColor = NSColor.black.cgColor
        maskLayer.allowsEdgeAntialiasing = true

        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.lineJoin = .round
        borderLayer.allowsEdgeAntialiasing = true

        updateLayers()
        setMirror(settings.isMirrored)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(settings: AppSettings) {
        self.settings = settings
        setMirror(settings.isMirrored)
        updateLayers()
    }

    func setMirror(_ mirrored: Bool) {
        guard let connection = previewLayer.connection,
              connection.isVideoMirroringSupported
        else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }

    override func layout() {
        super.layout()
        updateLayers()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateLayers()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func isInResizeBand(_ point: CGPoint) -> Bool {
        let margin = OverlayGeometry.resizeMargin
        return resizeHitPath.contains(CGPoint(x: point.x - margin, y: point.y - margin))
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isInResizeBand(point), let window {
            let margin = OverlayGeometry.resizeMargin
            let cursor = resizeCursor(at: point)
            resizeDrag = (window.frame.insetBy(dx: margin, dy: margin),
                          window.convertPoint(toScreen: event.locationInWindow), cursor)
            cursor.set()
        } else {
            window?.performDrag(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag = resizeDrag, let window else { return }
        let mouse = window.convertPoint(toScreen: event.locationInWindow)
        let delta = CGPoint(x: mouse.x - drag.mouse.x, y: mouse.y - drag.mouse.y)
        let frame = OverlayGeometry.resizedFrame(
            drag.frame,
            from: drag.mouse,
            delta: delta,
            within: (window.screen ?? NSScreen.main)?.visibleFrame
        )
        let margin = OverlayGeometry.resizeMargin
        window.setFrame(frame.insetBy(dx: -margin, dy: -margin), display: true)
        window.invalidateShadow()
        drag.cursor.set()
    }

    override func mouseUp(with event: NSEvent) {
        guard resizeDrag != nil else { return }
        resizeDrag = nil
        updateCursor(with: event)
        onResizeEnded?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let resizeTrackingArea { removeTrackingArea(resizeTrackingArea) }
        let area = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        resizeTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { updateCursor(with: event) }
    override func mouseMoved(with event: NSEvent) { updateCursor(with: event) }
    override func mouseExited(with event: NSEvent) {
        if resizeDrag == nil { NSCursor.arrow.set() }
    }

    private func updateCursor(with event: NSEvent) {
        if let drag = resizeDrag {
            drag.cursor.set()
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        (isInResizeBand(point) ? resizeCursor(at: point) : NSCursor.arrow).set()
    }

    private func resizeCursor(at point: CGPoint) -> NSCursor {
        let angle = atan2(point.y - bounds.midY, point.x - bounds.midX)
        let direction = (Int((angle / (.pi / 4)).rounded()) + 8) % 4
        return Self.resizeCursors[direction]
    }

    private static let resizeCursors: [NSCursor] = {
        // NSCursor.frameResize requires the macOS 15 SDK. The deployment target stays at
        // macOS 14, so guard the whole branch: `#available` alone does not compile with an
        // older SDK.
        #if compiler(>=6.0)
        if #available(macOS 15.0, *) {
            let positions: [NSCursor.FrameResizePosition] = [.right, .topRight, .top, .topLeft]
            return positions.map { position in
                let cursor = NSCursor.frameResize(position: position, directions: .all)
                return NSCursor(image: cursor.image, hotSpot: cursor.hotSpot)
            }
        }
        #endif
        return [.resizeLeftRight, diagonalCursors[0], .resizeUpDown, diagonalCursors[1]]
    }()

    private static let diagonalCursors: [NSCursor] = [CGFloat(1), CGFloat(-1)].map { slope in
        let image = NSImage(size: NSSize(width: 24, height: 24), flipped: false) { _ in
            let path = NSBezierPath()
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: 12 + x, y: 12 + y * slope)
            }
            path.move(to: point(-7, -7)); path.line(to: point(7, 7))
            path.move(to: point(1, 7)); path.line(to: point(7, 7)); path.line(to: point(7, 1))
            path.move(to: point(-1, -7)); path.line(to: point(-7, -7)); path.line(to: point(-7, -1))
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.white.setStroke(); path.lineWidth = 4; path.stroke()
            NSColor.black.setStroke(); path.lineWidth = 2; path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        onContextMenu?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = onContextMenu?() else { return }
        NSApp.activate(ignoringOtherApps: true)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func updateLayers() {
        let borderWidth = settings.borderWidth.value
        let margin = OverlayGeometry.resizeMargin
        let cameraBounds = bounds.insetBy(dx: margin, dy: margin)
        let shapeRect = CGRect(origin: .zero, size: cameraBounds.size).insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let path = ShapeGeometry.path(
            for: settings.shape,
            in: shapeRect,
            cornerRadius: CGFloat(settings.cornerRadius)
        )
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let zoom = max(1, CGFloat(settings.zoom))

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        cameraContainerLayer.frame = cameraBounds
        cameraContainerLayer.contentsScale = scale

        previewLayer.bounds = CGRect(origin: .zero, size: cameraContainerLayer.bounds.size)
        previewLayer.position = CGPoint(
            x: cameraContainerLayer.bounds.midX,
            y: cameraContainerLayer.bounds.midY
        )
        previewLayer.backgroundColor = NSColor.black.cgColor
        previewLayer.transform = CATransform3DMakeScale(zoom, zoom, 1)

        maskLayer.frame = cameraContainerLayer.bounds
        maskLayer.contentsScale = scale
        maskLayer.path = path

        borderLayer.frame = cameraBounds
        borderLayer.contentsScale = scale
        borderLayer.path = path
        borderLayer.lineWidth = borderWidth
        borderLayer.strokeColor = settings.borderColor.color.cgColor
        borderLayer.isHidden = borderWidth <= 0

        resizeBandLayer.frame = cameraBounds
        resizeBandLayer.contentsScale = scale
        resizeBandLayer.path = path
        resizeHitPath = path.copy(strokingWithWidth: OverlayGeometry.resizeBandWidth,
                                  lineCap: .round, lineJoin: .round, miterLimit: 10)

        CATransaction.commit()
    }
}
