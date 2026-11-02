import SwiftUI
import XCTest
@testable import StatusTrioCore

final class AppLanguageTests: XCTestCase {
    func testSupportsEnglishAndSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.allCases, [.english, .simplifiedChinese])
    }

    func testResolvesEveryChineseVariantToSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.resolved(preferredLanguages: ["zh-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolved(preferredLanguages: ["zh-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolved(preferredLanguages: ["zh-TW"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolved(preferredLanguages: ["zh-Hant-HK"]), .simplifiedChinese)
    }

    func testResolvesEnglishVariants() {
        XCTAssertEqual(AppLanguage.resolved(preferredLanguages: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.resolved(preferredLanguages: ["en_GB"]), .english)
    }

    func testUsesFirstSupportedSystemPreferenceThenEnglishFallback() {
        XCTAssertEqual(
            AppLanguage.resolved(preferredLanguages: ["fr-CA", "zh-Hans-US", "en-US"]),
            .simplifiedChinese
        )
        XCTAssertEqual(AppLanguage.resolved(preferredLanguages: ["ja-JP", "de-DE"]), .english)
        XCTAssertEqual(AppLanguage.resolved(preferredLanguages: ["yue-Hant"]), .english)
    }

    func testEveryLanguageUsesLeftToRightLayout() {
        for language in AppLanguage.allCases {
            XCTAssertEqual(language.layoutDirection, .leftToRight)
        }
    }
}
