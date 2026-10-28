// Floating Camera — MIT License. See LICENSE.

import AppKit
import AVFoundation
import QuartzCore

final class OverlayView: NSView {
    private let cameraContainerLayer = CALayer()
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let maskLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private var settings: AppSettings

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

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    private func updateLayers() {
        let borderWidth = settings.borderWidth.value
        let shapeRect = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let path = ShapeGeometry.path(
            for: settings.shape,
            in: shapeRect,
            cornerRadius: CGFloat(settings.cornerRadius)
        )
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let zoom = max(1, CGFloat(settings.zoom))

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        cameraContainerLayer.frame = bounds
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

        borderLayer.frame = bounds
        borderLayer.contentsScale = scale
        borderLayer.path = path
        borderLayer.lineWidth = borderWidth
        borderLayer.strokeColor = settings.borderColor.color.cgColor
        borderLayer.isHidden = borderWidth <= 0

        CATransaction.commit()
    }
}
