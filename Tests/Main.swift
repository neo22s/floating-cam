// Floating Camera — MIT License. See LICENSE.

import AppKit
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
        check(CameraResolution.closest(to: .high) == .p1080, "high preset maps to 1080p")
        check(CameraResolution.closest(to: .medium) == .p480, "medium preset maps to 480p")
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
