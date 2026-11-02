@MainActor
enum IconGuideOnboardingPolicy {
    static func consumeIfNeeded(settings: SettingsStore) -> Bool {
        guard !settings.hasCompletedIconGuideOnboarding else { return false }
        settings.hasCompletedIconGuideOnboarding = true
        return true
    }

    static func shouldPresentGuide(settings: SettingsStore) -> Bool {
        consumeIfNeeded(settings: settings)
    }
}
