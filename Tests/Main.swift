// Floating Camera — MIT License. See LICENSE.

import AppKit
import AVFoundation
import Darwin
import Foundation

@main
struct TestMain {
    static var failures = 0

    static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        if condition() {
            print("ok   \(name)")
        } else {
            failures += 1
            print("FAIL \(name)")
        }
    }

    static func equal<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
        check(actual == expected, "\(name) — expected \(expected), got \(actual)")
    }

    static func main() {
        testSettings()
        testSettingsStore()
        testOverlayGeometry()
        testOverlayResize()
        testShapePaths()
        testLocalization()
        testFrameRateSelection()
        testCameraResolution()
        testVersion()
        testReleaseParsing()

        if failures > 0 {
            print("\n\(failures) test(s) failed")
            exit(1)
        }
        print("\nAll tests passed")
    }

    static func testSettings() {
        let defaults = AppSettings()
        equal(defaults.shape, .roundedSquare, "default shape")
        equal(defaults.customWidth, 320, "default width")
        equal(defaults.cornerRadius, 16, "default corner radius")
        equal(defaults.opacity, 1, "default opacity")
        equal(defaults.zoom, 1, "default zoom")
        equal(defaults.frameRate, .fps30, "default frame rate")
        equal(defaults.resolution, .p720, "default resolution")
        equal(defaults.language, .system, "default language")
        equal(defaults.borderWidth, .thin, "default border width")
        equal(defaults.borderColor, .white, "default border color")
        check(defaults.isMirrored, "default mirror")
        check(defaults.isAlwaysOnTop, "default always on top")

        let encoded = try! JSONEncoder().encode(defaults)
        let decoded = try! JSONDecoder().decode(AppSettings.self, from: encoded)
        equal(decoded, defaults, "settings JSON round trip")

        let empty = try! JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        equal(empty, defaults, "empty settings use defaults")

        let partial = try! JSONDecoder().decode(
            AppSettings.self,
            from: Data(#"{"shape":"circle","opacity":0.5,"customWidth":500,"language":"spanish","frameRate":60}"#.utf8)
        )
        equal(partial.shape, .circle, "partial shape")
        equal(partial.opacity, 0.5, "partial opacity")
        equal(partial.customWidth, 500, "partial width")
        equal(partial.language, .spanish, "partial language")
        equal(partial.frameRate, .fps60, "partial frame rate")

        let legacy = try! JSONDecoder().decode(
            AppSettings.self,
            from: Data(#"{"size":"large","shape":"heart"}"#.utf8)
        )
        equal(legacy.shape, .heart, "legacy settings keep shape")
        equal(legacy.customWidth, 320, "legacy size key falls back to 320")

        var extreme = AppSettings()
        extreme.opacity = 0
        extreme.cornerRadius = 999
        extreme.zoom = 99
        extreme.customWidth = 10
        let normalized = extreme.normalized()
        equal(normalized.opacity, 0.1, "normalize low opacity")
        equal(normalized.cornerRadius, 100, "normalize high corner radius")
        equal(normalized.zoom, 3, "normalize high zoom")
        equal(normalized.customWidth, 160, "normalize low width")

        extreme.opacity = 2
        extreme.cornerRadius = -1
        extreme.zoom = -1
        extreme.customWidth = 2000
        let normalizedHigh = extreme.normalized()
        equal(normalizedHigh.opacity, 1, "normalize high opacity")
        equal(normalizedHigh.cornerRadius, 0, "normalize low corner radius")
        equal(normalizedHigh.zoom, 1, "normalize low zoom")
        equal(normalizedHigh.customWidth, 800, "normalize high width")
    }

    static func testSettingsStore() {
        let suite = "FloatingCameraTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsStore(defaults: defaults)
        equal(store.load(), AppSettings(), "store starts with defaults")

        var settings = AppSettings()
        settings.shape = .star
        settings.customWidth = 480
        settings.language = .spanish
        settings.frameRate = .fps15
        store.save(settings)
        equal(store.load(), settings, "store round trip")

        defaults.removePersistentDomain(forName: suite)
    }

    static func testOverlayGeometry() {
        let cameraAspect = CGSize(width: 1280, height: 720)
        var settings = AppSettings()
        settings.customWidth = 320

        settings.shape = .roundedSquare
        equal(OverlayGeometry.size(for: settings, cameraAspect: cameraAspect), CGSize(width: 320, height: 320), "rounded square size")
        settings.shape = .rectangle
        equal(OverlayGeometry.size(for: settings, cameraAspect: cameraAspect), CGSize(width: 320, height: 180), "rectangle size")
        settings.shape = .capsule
        equal(OverlayGeometry.size(for: settings, cameraAspect: cameraAspect), CGSize(width: 320, height: 213), "capsule size")
        settings.shape = .circle
        equal(OverlayGeometry.size(for: settings, cameraAspect: cameraAspect), CGSize(width: 320, height: 320), "circle size")

        settings.customWidth = 160
        settings.shape = .rectangle
        equal(OverlayGeometry.size(for: settings, cameraAspect: cameraAspect), CGSize(width: 160, height: 90), "minimum rectangle aspect")

        settings.shape = .rectangle
        check(abs(OverlayGeometry.aspect(for: settings, cameraAspect: cameraAspect) - 16.0 / 9.0) < 0.0001, "rectangle aspect")
        settings.shape = .capsule
        equal(OverlayGeometry.aspect(for: settings, cameraAspect: cameraAspect), 1.5, "capsule aspect")
        settings.shape = .circle
        equal(OverlayGeometry.aspect(for: settings, cameraAspect: cameraAspect), 1, "circle aspect")

        equal(OverlayGeometry.minimumWidth(for: 1), 120, "minimum square width")
        equal(OverlayGeometry.minimumWidth(for: 16.0 / 9.0), 160, "minimum rectangle width")

        let visible = NSRect(x: 0, y: 95, width: 1470, height: 828)
        let size = CGSize(width: 320, height: 320)
        equal(OverlayGeometry.centeredOrigin(for: size, visibleFrame: visible), CGPoint(x: 575, y: 349), "centered origin")
        equal(OverlayGeometry.defaultOrigin(for: size, visibleFrame: visible), CGPoint(x: 1126, y: 119), "default origin")

        let offscreen = NSRect(x: -100, y: -100, width: 320, height: 320)
        equal(OverlayGeometry.clampedFrame(offscreen, within: visible), NSRect(x: 0, y: 95, width: 320, height: 320), "clamp top-left")
        let bottomRight = NSRect(x: 1400, y: 900, width: 320, height: 320)
        equal(OverlayGeometry.clampedFrame(bottomRight, within: visible), NSRect(x: 1150, y: 603, width: 320, height: 320), "clamp bottom-right")
    }

    static func testOverlayResize() {
        _ = NSApplication.shared
        var settings = AppSettings()
        settings.shape = .circle
        let initial = NSRect(x: 100, y: 200, width: 320, height: 320)
        let controller = OverlayWindowController(
            session: AVCaptureSession(), settings: settings, frame: initial,
            onOriginChanged: { _ in }
        )
        let window = controller.window!
        let view = window.contentView as! OverlayView
        view.layoutSubtreeIfNeeded()
        equal(controller.windowFrame, initial, "resize margin preserves camera size and position")
        check(view.isInResizeBand(CGPoint(x: 325, y: 170)), "circle band includes inner half")
        check(view.isInResizeBand(CGPoint(x: 335, y: 170)), "circle band includes outer half")
        check(!view.isInResizeBand(CGPoint(x: 310, y: 170)), "circle interior remains movable")
        check(!view.isInResizeBand(CGPoint(x: 15, y: 15)), "circle bounding corner does not resize")
        check(!view.isInResizeBand(CGPoint(x: 345, y: 170)), "outside the band does not resize")

        var resizedFrame: NSRect?
        controller.onResize = { resizedFrame = $0 }
        func event(_ type: NSEvent.EventType, at point: CGPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                               windowNumber: window.windowNumber, context: nil,
                               eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        view.mouseMoved(with: event(.mouseMoved, at: CGPoint(x: 335, y: 170)))
        check(NSCursor.current != NSCursor.arrow, "hovering resize band changes cursor")
        view.mouseMoved(with: event(.mouseMoved, at: CGPoint(x: 170, y: 170)))
        equal(NSCursor.current, NSCursor.arrow, "hovering interior restores arrow cursor")
        for x: CGFloat in [325, 335] {
            controller.setFrame(initial)
            view.layoutSubtreeIfNeeded()
            resizedFrame = nil
            view.mouseDown(with: event(.leftMouseDown, at: CGPoint(x: x, y: 170)))
            view.mouseDragged(with: event(.leftMouseDragged, at: CGPoint(x: x + 40, y: 170)))
            let frame = controller.windowFrame
            check(frame.width > 320, "both halves of the band resize: \(x)")
            equal(frame.width, frame.height, "circle stays circular")
            check(abs(frame.midX - initial.midX) <= 0.5 && abs(frame.midY - initial.midY) <= 0.5,
                  "resize preserves center within AppKit pixel rounding")
            check(resizedFrame == nil, "size is saved on release")
            view.mouseUp(with: event(.leftMouseUp, at: CGPoint(x: 10, y: 10)))
            equal(resizedFrame, frame, "resize reports camera size and position without margin")
        }
        controller.setFrame(initial)
        for shape in OverlayShape.allCases {
            settings.shape = shape
            controller.apply(settings: settings)
            view.layoutSubtreeIfNeeded()
            if shape == .circle || shape == .heart || shape == .star {
                check(!view.isInResizeBand(CGPoint(x: 15, y: 15)), "transparent corner does not resize: \(shape)")
            }
            var inside = false
            var outside = false
            let path = ShapeGeometry.path(for: shape, in: CGRect(x: 11, y: 11, width: 318, height: 318), cornerRadius: 16)
            for x in stride(from: 0, through: 340, by: 5) {
                for y in stride(from: 0, through: 340, by: 5) {
                    let point = CGPoint(x: x, y: y)
                    if view.isInResizeBand(point) {
                        if path.contains(point) { inside = true } else { outside = true }
                    }
                }
            }
            check(inside && outside, "resize band straddles shape perimeter: \(shape)")
        }
        for aspect: CGFloat in [1, 16.0 / 9.0, 9.0 / 16.0, 1.5, 4.0 / 3.0] {
            let frame = NSRect(x: -500, y: 200, width: 320, height: 320 / aspect)
            for direction in [CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: -1)] {
                let point = CGPoint(x: frame.midX + direction.x * frame.width / 2,
                                    y: frame.midY + direction.y * frame.height / 2)
                let delta = CGPoint(x: direction.x * 40, y: direction.y * 40)
                let resized = OverlayGeometry.resizedFrame(frame, from: point, delta: delta)
                check(resized.width > frame.width, "perimeter drag grows size: \(aspect), \(direction)")
                check(abs(resized.width / resized.height - aspect) < 0.0001, "perimeter drag preserves aspect")
                check(abs(resized.midX - frame.midX) < 0.0001 && abs(resized.midY - frame.midY) < 0.0001, "perimeter drag preserves center")
                let large = OverlayGeometry.resizedFrame(frame, from: point,
                    delta: CGPoint(x: delta.x * 100, y: delta.y * 100))
                equal(large.width, 800, "perimeter drag maximum")
                let small = OverlayGeometry.resizedFrame(frame, from: point,
                    delta: CGPoint(x: -delta.x * 100, y: -delta.y * 100))
                equal(small.width, 160, "perimeter drag minimum")
            }
            equal(OverlayGeometry.resizedFrame(frame, from: CGPoint(x: frame.midX, y: frame.midY), delta: .zero), frame, "center cannot start resizing")
        }
    }

    static func testShapePaths() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)

        for shape in OverlayShape.allCases {
            let path = ShapeGeometry.path(for: shape, in: rect, cornerRadius: 24)
            check(!path.isEmpty, "path exists: \(shape.rawValue)")
            let box = path.boundingBoxOfPath
            check(box.minX >= rect.minX - 1 && box.maxX <= rect.maxX + 1, "path x bounds: \(shape.rawValue)")
            check(box.minY >= rect.minY - 1 && box.maxY <= rect.maxY + 1, "path y bounds: \(shape.rawValue)")
        }

        check(OverlayShape.square.allowsCornerRadius, "square allows rounding")
        check(OverlayShape.circle.allowsCornerRadius == false, "circle has no rounding slider")

        let circle = ShapeGeometry.path(for: .circle, in: rect, cornerRadius: 0)
        equal(circle.boundingBoxOfPath, rect, "circle bounding box")
        let square = ShapeGeometry.path(for: .square, in: rect, cornerRadius: 0)
        equal(square.boundingBoxOfPath, rect, "square bounding box")
        check(ShapeGeometry.path(for: .circle, in: .zero, cornerRadius: 0).isEmpty, "empty rect gives empty path")
    }

    static func testLocalization() {
        L10n.language = .english
        equal(L10n.s("Hello", "Hola"), "Hello", "english string")
        equal(OverlayShape.circle.title, "Circle", "english shape")
        equal(BorderColor.white.title, "White", "english border color")
        equal(BorderColor.red.title, "Red", "english red border color")
        equal(FrameRate.fps15.detail, "Low power", "english frame rate detail")
        equal(AppLanguage.system.title, "System", "english system language")
        equal(AppLanguage.spanish.title, "Spanish", "english language name")

        L10n.language = .spanish
        equal(L10n.s("Hello", "Hola"), "Hola", "spanish string")
        equal(OverlayShape.circle.title, "Círculo", "spanish shape")
        equal(BorderColor.white.title, "Blanco", "spanish border color")
        equal(BorderColor.red.title, "Rojo", "spanish red border color")
        equal(FrameRate.fps15.detail, "Bajo consumo", "spanish frame rate detail")
        equal(AppLanguage.system.title, "Sistema", "spanish system language")
        equal(AppLanguage.spanish.title, "Español", "spanish language name")

        L10n.language = .system
    }

    static func testFrameRateSelection() {
        check(FrameRate.best(requested: .fps60, within: [15.0...30.0]) == .fps30, "60 fps falls back to 30")
        check(FrameRate.best(requested: .fps15, within: [15.0...30.0]) == .fps15, "15 fps is supported")
        check(FrameRate.best(requested: .fps24, within: [15.0...30.0]) == .fps24, "24 fps is supported")
        check(FrameRate.best(requested: .fps30, within: [60.0...60.0]) == .fps60, "30 fps falls back to 60")
        check(FrameRate.best(requested: .fps30, within: [25.0...28.0]) == nil, "unsupported ranges give no match")
    }

    static func testCameraResolution() {
        equal(CameraResolution.p480.preset, .medium, "480p preset")
        equal(CameraResolution.p720.preset, .hd1280x720, "720p preset")
        equal(CameraResolution.p1080.preset, .hd1920x1080, "1080p preset")
        equal(CameraResolution.p4K.preset, .hd4K3840x2160, "4K preset")
        equal(CameraResolution.p4K.title, "4K", "4K title")
        equal(CameraResolution.p4K.detail, "3840 × 2160", "4K detail")
        check(CameraResolution.closest(to: .hd4K3840x2160) == .p4K, "4K preset maps to 4K")
        check(CameraResolution.closest(to: .high) == .p1080, "high preset maps to 1080p")
        check(CameraResolution.closest(to: .medium) == .p480, "medium preset maps to 480p")
        equal(CameraResolution.p4K.lowerResolutions, [.p1080, .p720, .p480], "4K falls back downwards")
        equal(CameraResolution.p720.lowerResolutions, [.p480], "720p falls back to 480p")
        equal(CameraResolution.p480.lowerResolutions, [], "480p has no fallback")
    }

    static func testVersion() {
        check(Version.isNewer("1.0.1", than: "1.0.0"), "patch version is newer")
        check(Version.isNewer("2.0", than: "1.9.9"), "major version is newer")
        check(Version.isNewer("v1.2.0", than: "1.1.9"), "v-prefixed tag is newer")
        check(!Version.isNewer("1.0.0", than: "1.0"), "short versions compare equal")
        check(!Version.isNewer("1.0.0", than: "1.0.0"), "equal versions are not newer")
    }

    static func testReleaseParsing() {
        let json = """
        {
          "tag_name": "v1.2.3",
          "html_url": "https://github.com/owner/repo/releases/tag/v1.2.3",
          "assets": [
            {"name": "source.zip", "browser_download_url": "https://example.com/source.zip"},
            {"name": "FloatingCamera.zip", "browser_download_url": "https://example.com/FloatingCamera.zip"}
          ]
        }
        """
        let release = GitHubRelease.parse(Data(json.utf8))
        equal(release?.version, "1.2.3", "release version")
        equal(release?.pageURL.absoluteString, "https://github.com/owner/repo/releases/tag/v1.2.3", "release page url")
        equal(release?.assetURL?.absoluteString, "https://example.com/FloatingCamera.zip", "preferred release asset")
        check(GitHubRelease.parse(Data("{}".utf8)) == nil, "invalid release JSON")
    }
}
