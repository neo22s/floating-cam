// Floating Camera — MIT License. See LICENSE.

import AppKit
import AVFoundation

final class AppController {
    private(set) var settings: AppSettings
    private(set) var cameras: [CameraDeviceInfo] = []
    private(set) var isOverlayVisible = false

    private let store = SettingsStore()
    private let camera = CameraManager()
    private lazy var menu = MenuController(app: self)
    private lazy var updater = Updater()
    private var overlay: OverlayWindowController?
    private var hotKey: GlobalHotKey?
    private var screenObserver: NSObjectProtocol?
    private var saveWorkItem: DispatchWorkItem?

    private var cameraAspect = CGSize(width: 16, height: 9)
    private var wantsOverlayVisible = true
    private var isStartingCamera = false
    private var isSwitchingCamera = false

    var activeCameraID: String? { camera.activeDeviceID }

    init() {
        settings = store.load()
        L10n.language = settings.language

        camera.onDevicesChanged = { [weak self] devices in
            self?.handleDevices(devices)
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        saveWorkItem?.cancel()
    }

    func start() {
        menu.present()
        hotKey = GlobalHotKey { [weak self] in
            self?.toggleOverlay()
        }
        hotKey?.register()
        showOverlay()

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.updater.checkIfDue()
        }
    }

    func checkForUpdates() {
        updater.checkNow()
    }

    func setLanguage(_ language: AppLanguage) {
        guard settings.language != language else { return }
        settings.language = language
        L10n.language = language
        saveSoon()
        menu.updateStatusIcon()
    }

    func shutdown() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        saveNow()
        camera.shutdown()
        hotKey?.unregister()
        hotKey = nil
    }

    func toggleOverlay() {
        isOverlayVisible ? hideOverlay() : showOverlay()
    }

    func showOverlay() {
        wantsOverlayVisible = true
        if let overlay {
            overlay.show()
            setOverlayVisible(true)
        }
        ensureCameraRunning()
    }

    func hideOverlay() {
        wantsOverlayVisible = false
        overlay?.hide()
        setOverlayVisible(false)
        camera.stop()
    }

    func setShape(_ shape: OverlayShape) {
        guard settings.shape != shape else { return }
        settings.shape = shape
        saveSoon()
        updateGeometry(keepCenter: true)
        applyOverlaySettings()
    }

    func setCustomSize(_ width: Double) {
        settings.customWidth = min(max(width, 160), 800)
        saveSoon()
        updateGeometry(keepCenter: true)
        applyOverlaySettings()
    }

    func setCornerRadius(_ radius: Double) {
        settings.cornerRadius = min(max(radius, 0), 100)
        saveSoon()
        applyOverlaySettings()
    }

    func setBorderWidth(_ width: BorderWidth) {
        guard settings.borderWidth != width else { return }
        settings.borderWidth = width
        saveSoon()
        applyOverlaySettings()
    }

    func setBorderColor(_ color: BorderColor) {
        guard settings.borderColor != color else { return }
        settings.borderColor = color
        saveSoon()
        applyOverlaySettings()
    }

    func setOpacity(_ opacity: Double) {
        settings.opacity = min(max(opacity, 0.1), 1)
        saveSoon()
        applyOverlaySettings()
    }

    func setZoom(_ zoom: Double) {
        settings.zoom = min(max(zoom, 1), 3)
        saveSoon()
        applyOverlaySettings()
    }

    func toggleMirror() {
        settings.isMirrored.toggle()
        saveSoon()
        applyOverlaySettings()
    }

    func toggleAlwaysOnTop() {
        settings.isAlwaysOnTop.toggle()
        saveSoon()
        applyOverlaySettings()
    }

    func selectCamera(id: String) {
        guard !isSwitchingCamera, id != camera.activeDeviceID else { return }
        isSwitchingCamera = true

        camera.switchCamera(to: id) { [weak self] result in
            guard let self else { return }
            self.isSwitchingCamera = false

            switch result {
            case .success(let info):
                self.handleCameraInfo(info)
            case .failure(let error):
                self.settings.cameraID = self.camera.activeDeviceID
                self.saveSoon()
                self.showError(error)
            }
        }
    }

    func setResolution(_ resolution: CameraResolution) {
        guard resolution != settings.resolution else { return }
        camera.setResolution(resolution) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let info):
                self.handleCameraInfo(info)
            case .failure(let error):
                self.showError(error)
            }
        }
    }

    func setFrameRate(_ frameRate: FrameRate) {
        guard frameRate != settings.frameRate else { return }
        camera.setFrameRate(frameRate) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let info):
                self.handleCameraInfo(info)
            case .failure(let error):
                self.showError(error)
            }
        }
    }

    func resetPosition() {
        guard let overlay else { return }
        let size = OverlayGeometry.size(for: settings, cameraAspect: cameraAspect)
        guard let screen = overlay.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let origin = OverlayGeometry.centeredOrigin(for: size, on: screen)
        let frame = OverlayGeometry.clampedFrame(NSRect(origin: origin, size: size), to: screen)
        overlay.setFrame(frame)
        settings.setOrigin(frame.origin)
        saveSoon()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func ensureCameraRunning() {
        guard !isStartingCamera else { return }
        isStartingCamera = true

        camera.start(
            preferredCameraID: settings.cameraID,
            resolution: settings.resolution,
            frameRate: settings.frameRate
        ) { [weak self] result in
            guard let self else { return }
            self.isStartingCamera = false

            switch result {
            case .success(let info):
                self.cameras = self.camera.devices
                self.handleCameraInfo(info)

                if self.wantsOverlayVisible, self.overlay != nil {
                    self.overlay?.show()
                    self.setOverlayVisible(true)
                } else {
                    self.overlay?.hide()
                    self.setOverlayVisible(false)
                    self.camera.stop()
                }
            case .failure(let error):
                self.overlay?.hide()
                self.setOverlayVisible(false)
                self.showError(error)
            }
        }
    }

    private func handleCameraInfo(_ info: CameraSessionInfo) {
        let previousAspect = cameraAspect
        cameraAspect = info.device.aspectRatio
        settings.cameraID = info.device.id
        settings.resolution = info.resolution
        settings.frameRate = info.frameRate
        saveSoon()

        if overlay == nil {
            createOverlay(session: info.session)
            return
        }

        if settings.shape.fixedAspect == nil, previousAspect != cameraAspect {
            updateGeometry(keepCenter: true)
        }
        applyOverlaySettings()
    }

    private func createOverlay(session: AVCaptureSession) {
        let size = OverlayGeometry.size(for: settings, cameraAspect: cameraAspect)
        let savedFrame = settings.origin.map { NSRect(origin: $0, size: size) }
        let savedScreen = savedFrame.flatMap(OverlayGeometry.screen(for:))
        guard let screen = savedScreen ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let origin = savedScreen != nil ? (settings.origin ?? OverlayGeometry.defaultOrigin(for: size, on: screen))
                                        : OverlayGeometry.defaultOrigin(for: size, on: screen)
        let frame = OverlayGeometry.clampedFrame(NSRect(origin: origin, size: size), to: screen)

        let controller = OverlayWindowController(
            session: session,
            settings: settings,
            frame: frame
        ) { [weak self] origin in
            self?.persistOrigin(origin)
        }
        overlay = controller
        settings.customWidth = Double(frame.width)
        settings.setOrigin(frame.origin)
        saveSoon()
        controller.apply(settings: settings)
    }

    private func updateGeometry(keepCenter: Bool) {
        guard let overlay else { return }
        let size = OverlayGeometry.size(for: settings, cameraAspect: cameraAspect)
        guard let screen = overlay.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let current = overlay.windowFrame
        let origin: CGPoint
        if keepCenter, current.width > 0, current.height > 0 {
            origin = CGPoint(
                x: current.midX - size.width / 2,
                y: current.midY - size.height / 2
            )
        } else {
            origin = OverlayGeometry.defaultOrigin(for: size, on: screen)
        }

        let frame = OverlayGeometry.clampedFrame(NSRect(origin: origin, size: size), to: screen)
        overlay.setFrame(frame)
        settings.customWidth = Double(frame.width)
        settings.setOrigin(frame.origin)
        saveSoon()
    }

    private func applyOverlaySettings() {
        overlay?.apply(settings: settings)
    }

    private func persistOrigin(_ origin: CGPoint) {
        guard settings.origin != origin else { return }
        settings.setOrigin(origin)
        saveSoon()
    }

    private func handleDevices(_ devices: [CameraDeviceInfo]) {
        cameras = devices

        if devices.isEmpty {
            if isOverlayVisible {
                hideOverlay()
                showError(CameraError.noCamera)
            }
            return
        }

        guard !isStartingCamera, !isSwitchingCamera,
              let activeID = camera.activeDeviceID,
              !devices.contains(where: { $0.id == activeID }),
              let first = devices.first
        else { return }

        selectCamera(id: first.id)
    }

    private func handleScreenChange() {
        guard let overlay else { return }
        let frame = overlay.windowFrame
        guard let screen = OverlayGeometry.screen(for: frame) ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let clamped = OverlayGeometry.clampedFrame(frame, to: screen)
        guard clamped != frame else { return }

        overlay.setFrame(clamped)
        settings.setOrigin(clamped.origin)
        saveSoon()
    }

    private func setOverlayVisible(_ visible: Bool) {
        guard isOverlayVisible != visible else { return }
        isOverlayVisible = visible
        menu.updateStatusIcon()
    }

    private func saveSoon() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        store.save(settings)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.s("Camera Error", "Error de cámara")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning

        if let cameraError = error as? CameraError, case .permissionDenied = cameraError {
            alert.addButton(withTitle: L10n.s("Open System Settings", "Abrir Ajustes del Sistema"))
            alert.addButton(withTitle: L10n.s("Cancel", "Cancelar"))
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                openCameraSettings()
            }
        } else {
            alert.addButton(withTitle: L10n.s("OK", "Aceptar"))
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    private func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
