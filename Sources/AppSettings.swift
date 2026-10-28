// Floating Camera — MIT License. See LICENSE.

import AppKit
import AVFoundation
import Foundation

enum OverlayShape: String, CaseIterable, Codable {
    case rectangle
    case roundedSquare
    case square
    case circle
    case heart
    case star
    case hexagon
    case pentagon
    case diamond
    case capsule

    var title: String {
        switch self {
        case .rectangle: return L10n.s("Rectangle", "Rectángulo")
        case .roundedSquare: return L10n.s("Rounded Square", "Cuadrado redondeado")
        case .square: return L10n.s("Square", "Cuadrado")
        case .circle: return L10n.s("Circle", "Círculo")
        case .heart: return L10n.s("Heart", "Corazón")
        case .star: return L10n.s("Star", "Estrella")
        case .hexagon: return L10n.s("Hexagon", "Hexágono")
        case .pentagon: return L10n.s("Pentagon", "Pentágono")
        case .diamond: return L10n.s("Diamond", "Diamante")
        case .capsule: return L10n.s("Capsule", "Cápsula")
        }
    }

    /// `nil` means "use the camera's native aspect ratio".
    var fixedAspect: CGFloat? {
        switch self {
        case .rectangle: return nil
        case .capsule: return 1.5
        default: return 1
        }
    }

    var allowsCornerRadius: Bool {
        switch self {
        case .rectangle, .roundedSquare, .square:
            return true
        default:
            return false
        }
    }
}

enum CameraResolution: String, CaseIterable, Codable {
    case p480
    case p720
    case p1080

    var title: String {
        switch self {
        case .p480: return "480p"
        case .p720: return "720p"
        case .p1080: return "1080p"
        }
    }

    var detail: String {
        switch self {
        case .p480: return "640 × 480"
        case .p720: return "1280 × 720"
        case .p1080: return "1920 × 1080"
        }
    }

    var preset: AVCaptureSession.Preset {
        switch self {
        case .p480: return .medium
        case .p720: return .hd1280x720
        case .p1080: return .hd1920x1080
        }
    }

    static func closest(to preset: AVCaptureSession.Preset) -> CameraResolution? {
        switch preset {
        case .hd1920x1080, .high: return .p1080
        case .hd1280x720: return .p720
        case .medium: return .p480
        default: return nil
        }
    }
}

enum FrameRate: Int, CaseIterable, Codable {
    case fps15 = 15
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var title: String { "\(rawValue) fps" }

    var detail: String {
        switch self {
        case .fps15: return L10n.s("Low power", "Bajo consumo")
        case .fps24: return L10n.s("Cinematic", "Cinemático")
        case .fps30: return L10n.s("Default", "Predeterminado")
        case .fps60: return L10n.s("Smooth", "Suave")
        }
    }

    static func best(requested: FrameRate, within ranges: [ClosedRange<Double>]) -> FrameRate? {
        var best: FrameRate?
        var bestDistance = Double.greatestFiniteMagnitude

        for candidate in allCases {
            let value = Double(candidate.rawValue)
            let isSupported = ranges.contains {
                value >= $0.lowerBound && value <= $0.upperBound
            }
            guard isSupported else { continue }

            let distance = abs(value - Double(requested.rawValue))
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }

        return best
    }
}

enum BorderWidth: Int, CaseIterable, Codable {
    case none = 0
    case thin = 2
    case medium = 4
    case thick = 8

    var title: String {
        switch self {
        case .none: return L10n.s("None", "Ninguno")
        case .thin: return L10n.s("Thin", "Fino")
        case .medium: return L10n.s("Medium", "Medio")
        case .thick: return L10n.s("Thick", "Grueso")
        }
    }

    var detail: String {
        switch self {
        case .none: return ""
        default: return "\(rawValue) pt"
        }
    }

    var value: CGFloat { CGFloat(rawValue) }
}

enum BorderColor: String, CaseIterable, Codable {
    case white
    case black
    case gray
    case red
    case blue
    case green
    case pink
    case yellow
    case accent

    var title: String {
        switch self {
        case .white: return L10n.s("White", "Blanco")
        case .black: return L10n.s("Black", "Negro")
        case .gray: return L10n.s("Gray", "Gris")
        case .red: return L10n.s("Red", "Rojo")
        case .blue: return L10n.s("Blue", "Azul")
        case .green: return L10n.s("Green", "Verde")
        case .pink: return L10n.s("Pink", "Rosa")
        case .yellow: return L10n.s("Yellow", "Amarillo")
        case .accent: return L10n.s("Accent", "Acento")
        }
    }

    var color: NSColor {
        switch self {
        case .white: return .white
        case .black: return .black
        case .gray: return NSColor(srgbRed: 0.62, green: 0.62, blue: 0.62, alpha: 1)
        case .red: return NSColor(srgbRed: 0.95, green: 0.20, blue: 0.20, alpha: 1)
        case .blue: return NSColor(srgbRed: 0.30, green: 0.62, blue: 1.00, alpha: 1)
        case .green: return NSColor(srgbRed: 0.30, green: 0.84, blue: 0.47, alpha: 1)
        case .pink: return NSColor(srgbRed: 1.00, green: 0.40, blue: 0.62, alpha: 1)
        case .yellow: return NSColor(srgbRed: 1.00, green: 0.82, blue: 0.25, alpha: 1)
        case .accent: return .controlAccentColor
        }
    }
}

struct AppSettings: Codable, Equatable {
    var shape: OverlayShape = .roundedSquare
    var borderWidth: BorderWidth = .thin
    var borderColor: BorderColor = .white
    var opacity: Double = 1
    var cornerRadius: Double = 16
    var zoom: Double = 1
    var customWidth: Double = 320
    var isMirrored = true
    var isAlwaysOnTop = true
    var resolution: CameraResolution = .p720
    var frameRate: FrameRate = .fps30
    var language: AppLanguage = .system
    var cameraID: String?
    var originX: Double?
    var originY: Double?

    init() {}

    init(from decoder: Decoder) throws {
        self = AppSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shape = try container.decodeIfPresent(OverlayShape.self, forKey: .shape) ?? shape
        borderWidth = try container.decodeIfPresent(BorderWidth.self, forKey: .borderWidth) ?? borderWidth
        borderColor = try container.decodeIfPresent(BorderColor.self, forKey: .borderColor) ?? borderColor
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? opacity
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? cornerRadius
        zoom = try container.decodeIfPresent(Double.self, forKey: .zoom) ?? zoom
        customWidth = try container.decodeIfPresent(Double.self, forKey: .customWidth) ?? customWidth
        isMirrored = try container.decodeIfPresent(Bool.self, forKey: .isMirrored) ?? isMirrored
        isAlwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .isAlwaysOnTop) ?? isAlwaysOnTop
        resolution = try container.decodeIfPresent(CameraResolution.self, forKey: .resolution) ?? resolution
        frameRate = try container.decodeIfPresent(FrameRate.self, forKey: .frameRate) ?? frameRate
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? language
        cameraID = try container.decodeIfPresent(String.self, forKey: .cameraID)
        originX = try container.decodeIfPresent(Double.self, forKey: .originX)
        originY = try container.decodeIfPresent(Double.self, forKey: .originY)
    }

    var origin: CGPoint? {
        guard let originX, let originY else { return nil }
        return CGPoint(x: originX, y: originY)
    }

    mutating func setOrigin(_ origin: CGPoint?) {
        originX = origin.map { Double($0.x) }
        originY = origin.map { Double($0.y) }
    }

    func normalized() -> AppSettings {
        var copy = self
        copy.opacity = min(max(copy.opacity, 0.1), 1)
        copy.cornerRadius = min(max(copy.cornerRadius, 0), 100)
        copy.zoom = min(max(copy.zoom, 1), 3)
        copy.customWidth = min(max(copy.customWidth, 160), 800)
        if let id = copy.cameraID, id.isEmpty {
            copy.cameraID = nil
        }
        return copy
    }
}

final class SettingsStore {
    private let key = "FloatingCamera.settings.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return decoded.normalized()
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
