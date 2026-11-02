import XCTest
@testable import StatusTrioCore

@MainActor
final class ShortcutRecordingLocalizationTests: XCTestCase {
    func testDescriptionsExplainInputMethodAndAppConflictsInEveryLanguage() throws {
        let requiredTerms: [AppLanguage: (inputMethod: String, otherApp: String)] = [
            .english: ("input method", "another app"),
            .simplifiedChinese: ("输入法", "其他 App")
        ]

        for language in AppLanguage.allCases {
            let bundle = try XCTUnwrap(Localization.resourceBundle(for: language))
            let description = bundle.localizedString(
                forKey: LocalizationKey.settingsShortcutDescription.rawValue,
                value: nil,
                table: nil
            )
            let terms = try XCTUnwrap(requiredTerms[language])

            XCTAssertTrue(
                description.contains(terms.inputMethod),
                "\(language.rawValue) shortcut description is missing the input-method caveat"
            )
            XCTAssertTrue(
                description.contains(terms.otherApp),
                "\(language.rawValue) shortcut description is missing the other-app caveat"
            )
        }
    }

    func testFeedbackMapsToDistinctLocalizationKeys() {
        XCTAssertEqual(
            GlobalShortcutFeedback.invalidCombination.localizationKey,
            .settingsShortcutInvalid
        )
        XCTAssertEqual(
            GlobalShortcutFeedback.inputMethodConflict.localizationKey,
            .settingsShortcutInputMethodConflict
        )
        XCTAssertEqual(
            GlobalShortcutFeedback.conflict.localizationKey,
            .settingsShortcutUnavailable
        )
        XCTAssertEqual(
            GlobalShortcutFeedback.registrationFailed.localizationKey,
            .settingsShortcutRegistrationFailed
        )
        XCTAssertEqual(
            GlobalShortcutFeedback.restorationFailed.localizationKey,
            .settingsShortcutRestorationFailed
        )
    }
}
