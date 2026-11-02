import SwiftUI

struct IconGuideOnboardingView: View {
    static let contentWidth: CGFloat = 640
    static let footerHeight: CGFloat = 32

    @ObservedObject var settings: SettingsStore
    @EnvironmentObject private var localization: Localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: IconGuidePage = .anatomy
    @State private var menuBarHelp = MenuBarHelpPresentation()
    let onCustomize: () -> Void
    let onDone: () -> Void
    /// Reports the view's intrinsic content height so the hosting window can
    /// size itself to the current page and language instead of a fixed height.
    let onContentHeightChange: (CGFloat) -> Void

    init(
        settings: SettingsStore,
        initialPage: IconGuidePage = .anatomy,
        onCustomize: @escaping () -> Void,
        onDone: @escaping () -> Void,
        onContentHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.settings = settings
        _page = State(initialValue: initialPage)
        self.onCustomize = onCustomize
        self.onDone = onDone
        self.onContentHeightChange = onContentHeightChange
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                // Small secondary eyebrow so the page-specific heading inside
                // the content becomes the dominant title instead of competing
                // with a second full-size title.
                Text(localization.string(.guideTitle))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 16)

                pageIndicator
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 16) {
                Group {
                    switch page {
                    case .anatomy:
                        IconGuideView(
                            settings: settings,
                            isMenuBarHelpPresented: $menuBarHelp.isPresented
                        )
                    case .states:
                        IconGuideStateGalleryView(settings: settings)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Divider()

            footer
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .frame(width: Self.contentWidth)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: IconGuideContentHeightKey.self,
                    value: proxy.size.height
                )
            }
        )
        .onPreferenceChange(IconGuideContentHeightKey.self) { height in
            onContentHeightChange(height)
        }
    }

    private var pageIndex: Int {
        page == .anatomy ? 0 : 1
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            Text("\(pageIndex + 1) / 2")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                pageBar(for: .anatomy)
                pageBar(for: .states)
            }
        }
        .accessibilityHidden(true)
    }

    private func pageBar(for item: IconGuidePage) -> some View {
        Capsule()
            .fill(
                page == item
                    ? Color.accentColor
                    : Color.secondary.opacity(0.22)
            )
            .frame(width: page == item ? 18 : 8, height: 4)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(localization.string(.commonBack)) {
                show(.anatomy)
            }
            .opacity(page == .states ? 1 : 0)
            .disabled(page != .states)
            .accessibilityHidden(page != .states)

            Spacer(minLength: 8)

            Button(localization.string(.guideCustomize)) {
                completeOnboarding(onCustomize)
            }
                .opacity(page == .states ? 1 : 0)
                .disabled(page != .states)
                .accessibilityHidden(page != .states)

            primaryButton
        }
        .frame(height: Self.footerHeight)
    }

    private var primaryButton: some View {
        Button {
            if page == .anatomy {
                show(.states)
            } else {
                completeOnboarding(onDone)
            }
        } label: {
            ZStack {
                Text(localization.string(.guideNext))
                    .opacity(page == .anatomy ? 1 : 0)

                Text(localization.string(.guideDone))
                    .opacity(page == .states ? 1 : 0)
            }
        }
        .accessibilityLabel(
            localization.string(page == .anatomy ? .guideNext : .guideDone)
        )
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
    }

    private func show(_ destination: IconGuidePage) {
        menuBarHelp.prepareForPageChange()
        withAnimation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.22)
        ) {
            page = destination
        }
    }

    private func completeOnboarding(_ action: () -> Void) {
        action()
    }
}

/// Carries the guide's intrinsic content height up to the hosting controller so
/// the window can match the current page and language.
private struct IconGuideContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
