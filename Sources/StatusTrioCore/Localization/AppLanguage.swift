import AppKit
import SwiftUI

/// The app ships English and Simplified Chinese only.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var layoutDirection: LayoutDirection {
        .leftToRight
    }

    var isChinese: Bool {
        self == .simplifiedChinese
    }

    var nsLayoutDirection: NSUserInterfaceLayoutDirection {
        .leftToRight
    }

    static func resolved(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            if let match = match(identifier) {
                return match
            }
        }
        return .english
    }

    /// Any Chinese variant, including Traditional, resolves to Simplified
    /// Chinese; any English variant resolves to English.
    static func match(_ identifier: String) -> AppLanguage? {
        let normalized = identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        if normalized == "zh" || normalized.hasPrefix("zh-") {
            return .simplifiedChinese
        }

        if normalized == "en" || normalized.hasPrefix("en-") {
            return .english
        }

        return nil
    }
}
