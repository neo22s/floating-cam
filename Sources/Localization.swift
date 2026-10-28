// Floating Camera — MIT License. See LICENSE.

import Foundation

enum AppLanguage: String, CaseIterable, Codable {
    case system
    case english
    case spanish

    var title: String {
        switch self {
        case .system: return L10n.s("System", "Sistema")
        case .english: return "English"
        case .spanish: return L10n.s("Spanish", "Español")
        }
    }
}

enum L10n {
    static var language: AppLanguage = .system

    static var isSpanish: Bool {
        switch language {
        case .spanish:
            return true
        case .english:
            return false
        case .system:
            return Locale.preferredLanguages.first?.lowercased().hasPrefix("es") == true
        }
    }

    static func s(_ english: String, _ spanish: String) -> String {
        isSpanish ? spanish : english
    }
}
