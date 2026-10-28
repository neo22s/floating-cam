// Floating Camera — MIT License. See LICENSE.

import AppKit

final class MenuSliderView: NSView {
    private let titleLabel: NSTextField
    private let valueLabel = NSTextField(labelWithString: "")
    private let slider: NSSlider
    private let suffix: String

    var onChange: ((Double) -> Void)?

    var isEnabled: Bool {
        get { slider.isEnabled }
        set {
            slider.isEnabled = newValue
            titleLabel.textColor = newValue ? .labelColor : .disabledControlTextColor
            valueLabel.textColor = newValue ? .secondaryLabelColor : .disabledControlTextColor
        }
    }

    init(title: String, suffix: String, minimum: Double = 0, maximum: Double = 100) {
        self.suffix = suffix
        self.titleLabel = NSTextField(labelWithString: title)
        self.slider = NSSlider(value: minimum, minValue: minimum, maxValue: maximum, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 30))

        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .labelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right

        slider.controlSize = .small
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.setAccessibilityLabel(title)

        addSubview(titleLabel)
        addSubview(slider)
        addSubview(valueLabel)
        updateValueLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: Double) {
        slider.doubleValue = min(max(value, slider.minValue), slider.maxValue)
        updateValueLabel()
    }

    func setTitle(_ title: String) {
        titleLabel.stringValue = title
        slider.setAccessibilityLabel(title)
    }

    override func layout() {
        super.layout()
        let labelY = (bounds.height - 16) / 2
        titleLabel.frame = NSRect(x: 10, y: labelY, width: 110, height: 16)
        slider.frame = NSRect(x: 126, y: (bounds.height - 20) / 2, width: 112, height: 20)
        valueLabel.frame = NSRect(x: 244, y: labelY, width: 32, height: 16)
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        updateValueLabel()
        onChange?(sender.doubleValue)
    }

    private func updateValueLabel() {
        valueLabel.stringValue = "\(Int(slider.doubleValue.rounded()))\(suffix)"
    }
}

final class MenuController: NSObject, NSMenuDelegate {
    private weak var app: AppController?
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    private let toggleItem = NSMenuItem()
    private let opacityItem = NSMenuItem()
    private let radiusItem = NSMenuItem()
    private let zoomItem = NSMenuItem()
    private let opacitySlider = MenuSliderView(title: "Opacity", suffix: "%", minimum: 10)
    private let radiusSlider = MenuSliderView(title: "Rounding", suffix: "")
    private let zoomSlider = MenuSliderView(title: "Zoom", suffix: "%", minimum: 100, maximum: 300)
    private let sizeSlider = MenuSliderView(title: "Size", suffix: "", minimum: 160, maximum: 800)

    private let shapeItem = NSMenuItem(title: "Shape", action: nil, keyEquivalent: "")
    private let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
    private let cameraItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
    private let resolutionItem = NSMenuItem(title: "Resolution", action: nil, keyEquivalent: "")
    private let frameRateItem = NSMenuItem(title: "Frame Rate", action: nil, keyEquivalent: "")
    private let borderItem = NSMenuItem(title: "Border", action: nil, keyEquivalent: "")
    private let advancedItem = NSMenuItem(title: "Advanced", action: nil, keyEquivalent: "")
    private let mirrorItem = NSMenuItem(title: "Mirror", action: nil, keyEquivalent: "")
    private let alwaysOnTopItem = NSMenuItem(title: "Always on Top", action: nil, keyEquivalent: "")
    private let resetItem = NSMenuItem(title: "Reset Position", action: nil, keyEquivalent: "")
    private let updateItem = NSMenuItem(title: "Check for Updates…", action: nil, keyEquivalent: "")
    private let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: nil, keyEquivalent: "q")
    private let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")

    private let shapeMenu = NSMenu(title: "Shape")
    private let cameraMenu = NSMenu(title: "Camera")
    private let resolutionMenu = NSMenu(title: "Resolution")
    private let frameRateMenu = NSMenu(title: "Frame Rate")
    private let borderMenu = NSMenu(title: "Border")
    private let colorMenu = NSMenu(title: "Color")
    private let advancedMenu = NSMenu(title: "Advanced")
    private let languageMenu = NSMenu(title: "Language")

    init(app: AppController) {
        self.app = app
        super.init()
        build()
    }

    func present() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.imagePosition = .imageOnly
        item.menu = menu
        statusItem = item
        menu.delegate = self
        updateStatusIcon()
    }

    func updateStatusIcon() {
        guard let app else { return }
        let symbol = app.isOverlayVisible ? "camera.aperture" : "video.slash"
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let name = L10n.s("Floating Camera", "Cámara flotante")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: name)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        statusItem?.button?.image = image
        let state = app.isOverlayVisible
            ? L10n.s("visible", "visible")
            : L10n.s("hidden", "oculta")
        statusItem?.button?.toolTip = "\(name) — \(state)"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    func refresh() {
        guard let app else { return }
        let settings = app.settings
        applyLanguage()

        toggleItem.title = app.isOverlayVisible
            ? L10n.s("Hide Camera  ⌃⌥H", "Ocultar cámara  ⌃⌥H")
            : L10n.s("Show Camera  ⌃⌥H", "Mostrar cámara  ⌃⌥H")

        opacityItem.isEnabled = true
        radiusItem.isEnabled = true
        zoomItem.isEnabled = true
        opacitySlider.setValue(settings.opacity * 100)
        radiusSlider.setValue(settings.cornerRadius)
        zoomSlider.setValue(settings.zoom * 100)
        radiusItem.isHidden = !settings.shape.allowsCornerRadius
        radiusSlider.isEnabled = settings.shape.allowsCornerRadius

        for item in shapeMenu.items {
            guard let raw = item.representedObject as? String,
                  let shape = OverlayShape(rawValue: raw)
            else { continue }
            item.state = shape == settings.shape ? .on : .off
        }

        sizeItem.isEnabled = true
        sizeSlider.setValue(settings.customWidth)

        for item in resolutionMenu.items {
            guard let raw = item.representedObject as? String,
                  let resolution = CameraResolution(rawValue: raw)
            else { continue }
            item.state = resolution == settings.resolution ? .on : .off
        }
        resolutionItem.isEnabled = app.activeCameraID != nil

        for item in frameRateMenu.items {
            guard let frameRate = FrameRate(rawValue: item.tag) else { continue }
            item.state = frameRate == settings.frameRate ? .on : .off
        }
        frameRateItem.isEnabled = app.activeCameraID != nil

        for item in borderMenu.items where item.action == #selector(selectBorderWidth(_:)) {
            item.state = item.tag == settings.borderWidth.rawValue ? .on : .off
        }

        for item in colorMenu.items {
            guard let raw = item.representedObject as? String,
                  let color = BorderColor(rawValue: raw)
            else { continue }
            item.state = color == settings.borderColor ? .on : .off
        }

        for item in languageMenu.items {
            guard let raw = item.representedObject as? String,
                  let language = AppLanguage(rawValue: raw)
            else { continue }
            item.state = language == settings.language ? .on : .off
        }

        borderItem.image = swatch(settings.borderColor.color)
        mirrorItem.state = settings.isMirrored ? .on : .off
        alwaysOnTopItem.state = settings.isAlwaysOnTop ? .on : .off

        rebuildCameraMenu(devices: app.cameras, activeID: app.activeCameraID)
        updateStatusIcon()
    }

    private func applyLanguage() {
        cameraItem.title = L10n.s("Camera", "Cámara")
        shapeItem.title = L10n.s("Shape", "Forma")
        borderItem.title = L10n.s("Border", "Borde")
        advancedItem.title = L10n.s("Advanced", "Avanzado")
        opacityItem.title = L10n.s("Opacity", "Opacidad")
        radiusItem.title = L10n.s("Rounding", "Redondeo")
        zoomItem.title = L10n.s("Zoom", "Zoom")
        sizeItem.title = L10n.s("Size", "Tamaño")
        resolutionItem.title = L10n.s("Resolution", "Resolución")
        frameRateItem.title = L10n.s("Frame Rate", "FPS")
        mirrorItem.title = L10n.s("Mirror", "Espejo")
        alwaysOnTopItem.title = L10n.s("Always on Top", "Siempre encima")
        resetItem.title = L10n.s("Reset Position", "Restablecer posición")
        updateItem.title = L10n.s("Check for Updates…", "Buscar actualizaciones…")
        languageItem.title = L10n.s("Language", "Idioma")
        quitItem.title = L10n.s("Quit", "Salir")
        colorItem.title = L10n.s("Color", "Color")

        opacitySlider.setTitle(opacityItem.title)
        radiusSlider.setTitle(radiusItem.title)
        zoomSlider.setTitle(zoomItem.title)
        sizeSlider.setTitle(sizeItem.title)

        shapeMenu.title = shapeItem.title
        cameraMenu.title = cameraItem.title
        resolutionMenu.title = resolutionItem.title
        frameRateMenu.title = frameRateItem.title
        borderMenu.title = borderItem.title
        colorMenu.title = colorItem.title
        advancedMenu.title = advancedItem.title
        languageMenu.title = languageItem.title

        for item in shapeMenu.items {
            guard let raw = item.representedObject as? String,
                  let shape = OverlayShape(rawValue: raw)
            else { continue }
            item.title = shape.title
        }
        for item in resolutionMenu.items {
            guard let raw = item.representedObject as? String,
                  let resolution = CameraResolution(rawValue: raw)
            else { continue }
            item.title = "\(resolution.title)  (\(resolution.detail))"
        }
        for item in frameRateMenu.items {
            guard let frameRate = FrameRate(rawValue: item.tag) else { continue }
            item.title = "\(frameRate.title)  (\(frameRate.detail))"
        }
        for item in borderMenu.items where item.action == #selector(selectBorderWidth(_:)) {
            guard let width = BorderWidth(rawValue: item.tag) else { continue }
            item.title = width.detail.isEmpty ? width.title : "\(width.title)  (\(width.detail))"
        }
        for item in colorMenu.items {
            guard let raw = item.representedObject as? String,
                  let color = BorderColor(rawValue: raw)
            else { continue }
            item.title = color.title
        }
        for item in languageMenu.items {
            guard let raw = item.representedObject as? String,
                  let language = AppLanguage(rawValue: raw)
            else { continue }
            item.title = language.title
        }
    }

    private func build() {
        menu.autoenablesItems = false

        toggleItem.target = self
        toggleItem.action = #selector(toggleOverlay)

        opacityItem.title = "Opacity"
        opacityItem.view = opacitySlider
        opacitySlider.onChange = { [weak self] value in
            self?.app?.setOpacity(value / 100)
        }

        radiusItem.title = "Rounding"
        radiusItem.view = radiusSlider
        radiusSlider.onChange = { [weak self] value in
            self?.app?.setCornerRadius(value)
        }

        zoomItem.title = "Zoom"
        zoomItem.view = zoomSlider
        zoomSlider.onChange = { [weak self] value in
            self?.app?.setZoom(value / 100)
        }

        shapeItem.submenu = shapeMenu
        for shape in OverlayShape.allCases {
            let item = NSMenuItem(
                title: shape.title,
                action: #selector(selectShape(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = shape.rawValue
            shapeMenu.addItem(item)
        }

        sizeItem.view = sizeSlider
        sizeSlider.onChange = { [weak self] value in
            self?.app?.setCustomSize(value)
        }

        cameraItem.submenu = cameraMenu

        resolutionItem.submenu = resolutionMenu
        for resolution in CameraResolution.allCases {
            let item = NSMenuItem(
                title: "\(resolution.title)  (\(resolution.detail))",
                action: #selector(selectResolution(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = resolution.rawValue
            resolutionMenu.addItem(item)
        }

        frameRateItem.submenu = frameRateMenu
        for frameRate in FrameRate.allCases {
            let item = NSMenuItem(
                title: "\(frameRate.title)  (\(frameRate.detail))",
                action: #selector(selectFrameRate(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = frameRate.rawValue
            frameRateMenu.addItem(item)
        }

        languageItem.submenu = languageMenu
        for language in AppLanguage.allCases {
            let item = NSMenuItem(
                title: language.title,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            languageMenu.addItem(item)
        }

        borderItem.submenu = borderMenu
        for width in BorderWidth.allCases {
            let item = NSMenuItem(
                title: width.detail.isEmpty ? width.title : "\(width.title)  (\(width.detail))",
                action: #selector(selectBorderWidth(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = width.rawValue
            borderMenu.addItem(item)
        }
        borderMenu.addItem(.separator())
        colorItem.submenu = colorMenu
        borderMenu.addItem(colorItem)

        for color in BorderColor.allCases {
            let item = NSMenuItem(
                title: color.title,
                action: #selector(selectBorderColor(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = color.rawValue
            item.image = swatch(color.color)
            colorMenu.addItem(item)
        }

        mirrorItem.target = self
        mirrorItem.action = #selector(toggleMirror)

        alwaysOnTopItem.target = self
        alwaysOnTopItem.action = #selector(toggleAlwaysOnTop)

        resetItem.target = self
        resetItem.action = #selector(resetPosition)

        updateItem.target = self
        updateItem.action = #selector(checkForUpdates)

        quitItem.target = self
        quitItem.action = #selector(quit)
        quitItem.keyEquivalentModifierMask = .command

        advancedMenu.autoenablesItems = false
        advancedItem.submenu = advancedMenu
        advancedMenu.addItem(resolutionItem)
        advancedMenu.addItem(frameRateItem)
        advancedMenu.addItem(.separator())
        advancedMenu.addItem(mirrorItem)
        advancedMenu.addItem(alwaysOnTopItem)
        advancedMenu.addItem(.separator())
        advancedMenu.addItem(resetItem)
        advancedMenu.addItem(updateItem)
        advancedMenu.addItem(languageItem)

        menu.addItem(cameraItem)
        menu.addItem(shapeItem)
        menu.addItem(borderItem)
        menu.addItem(.separator())
        menu.addItem(sizeItem)
        menu.addItem(opacityItem)
        menu.addItem(radiusItem)
        menu.addItem(zoomItem)
        menu.addItem(.separator())
        menu.addItem(advancedItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    private func rebuildCameraMenu(devices: [CameraDeviceInfo], activeID: String?) {
        cameraMenu.removeAllItems()

        guard !devices.isEmpty else {
            let item = NSMenuItem(
                title: L10n.s("No Cameras Found", "No se encontraron cámaras"),
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            cameraMenu.addItem(item)
            return
        }

        for device in devices {
            let item = NSMenuItem(
                title: device.name,
                action: #selector(selectCamera(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = device.id
            item.state = device.id == activeID ? .on : .off
            cameraMenu.addItem(item)
        }
    }

    private func swatch(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            color.setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    @objc private func toggleOverlay() {
        app?.toggleOverlay()
    }

    @objc private func selectShape(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let shape = OverlayShape(rawValue: raw)
        else { return }
        app?.setShape(shape)
    }

    @objc private func selectCamera(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        app?.selectCamera(id: id)
    }

    @objc private func selectResolution(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let resolution = CameraResolution(rawValue: raw)
        else { return }
        app?.setResolution(resolution)
    }

    @objc private func selectFrameRate(_ sender: NSMenuItem) {
        guard let frameRate = FrameRate(rawValue: sender.tag) else { return }
        app?.setFrameRate(frameRate)
    }

    @objc private func selectBorderWidth(_ sender: NSMenuItem) {
        guard let width = BorderWidth(rawValue: sender.tag) else { return }
        app?.setBorderWidth(width)
    }

    @objc private func selectBorderColor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let color = BorderColor(rawValue: raw)
        else { return }
        app?.setBorderColor(color)
    }

    @objc private func toggleMirror() {
        app?.toggleMirror()
    }

    @objc private func toggleAlwaysOnTop() {
        app?.toggleAlwaysOnTop()
    }

    @objc private func resetPosition() {
        app?.resetPosition()
    }

    @objc private func checkForUpdates() {
        app?.checkForUpdates()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = AppLanguage(rawValue: raw)
        else { return }
        app?.setLanguage(language)
    }

    @objc private func quit() {
        app?.quit()
    }
}
