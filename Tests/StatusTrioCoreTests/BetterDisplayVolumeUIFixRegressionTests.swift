import CoreAudio
import Foundation
import XCTest
@testable import StatusTrioCore

@MainActor
final class BetterDisplayVolumeUIFixRegressionTests: XCTestCase {
    func testActiveDragCannotContinueIntoNewOutputUntilFreshBegin() {
        let first = outputIdentity(id: 41, uid: "audio-a")
        let second = outputIdentity(id: 42, uid: "audio-b")
        let firstInteraction = interactionIdentity(
            output: first,
            transitionGeneration: 0
        )
        let secondInteraction = interactionIdentity(
            output: second,
            transitionGeneration: 1
        )
        var emittedScalars: [Double] = []
        var finishCount = 0
        var interaction = VolumeControlInteraction(
            setVolume: { emittedScalars.append($0) },
            finishVolume: { finishCount += 1 }
        )

        interaction.receiveSystemState(
            identity: firstInteraction,
            scalar: 0.5,
            canAdjust: true
        )
        interaction.beginEditing()
        interaction.setSliderValue(
            0.8,
            identity: firstInteraction,
            canAdjust: true
        )
        interaction.receiveSystemState(
            identity: secondInteraction,
            scalar: 0.5,
            canAdjust: true
        )

        interaction.setSliderValue(
            0.9,
            identity: secondInteraction,
            canAdjust: true
        )
        interaction.endEditing(identity: secondInteraction)

        XCTAssertEqual(interaction.value, 0.5, accuracy: 0.000_001)
        XCTAssertFalse(interaction.isEditing)
        XCTAssertEqual(emittedScalars, [0.8])
        XCTAssertEqual(finishCount, 0)

        interaction.beginEditing()
        interaction.setSliderValue(
            0.9,
            identity: secondInteraction,
            canAdjust: true
        )
        interaction.endEditing(identity: secondInteraction)

        XCTAssertEqual(emittedScalars, [0.8, 0.9])
        XCTAssertEqual(finishCount, 1)
    }

    func testMouseUpAfterInterruptedPointerDragUnlocksKeyboardWithoutFlush() {
        let first = interactionIdentity(
            output: outputIdentity(id: 40, uid: "audio-pointer-a"),
            transitionGeneration: 0
        )
        let second = interactionIdentity(
            output: outputIdentity(id: 41, uid: "audio-pointer-b"),
            transitionGeneration: 1
        )
        var emittedScalars: [Double] = []
        var finishCount = 0
        var interaction = VolumeControlInteraction(
            setVolume: { emittedScalars.append($0) },
            finishVolume: { finishCount += 1 }
        )

        interaction.receiveSystemState(
            identity: first,
            scalar: 0.5,
            canAdjust: true
        )
        interaction.beginEditing()
        interaction.setSliderValue(
            0.8,
            identity: first,
            canAdjust: true
        )
        interaction.receiveSystemState(
            identity: second,
            scalar: 0.4,
            canAdjust: true
        )

        // The old pointer cannot continue writing before its mouseup.
        interaction.setSliderValue(
            0.9,
            identity: second,
            canAdjust: true
        )
        XCTAssertEqual(emittedScalars, [0.8])

        // Mouseup reports the current output identity, not the old one. It
        // consumes the transition lock without flushing the discarded draft.
        interaction.endEditing(identity: second)
        XCTAssertEqual(finishCount, 0)

        // Keyboard/VoiceOver input can resume without a pointer begin.
        interaction.setSliderValue(
            0.6,
            identity: second,
            canAdjust: true
        )

        XCTAssertEqual(emittedScalars, [0.8, 0.6])
        XCTAssertEqual(finishCount, 0)
    }

    func testUnmanagedKeyboardPendingRouteChangeDoesNotLockLaterKeyboardUpdate() {
        let first = interactionIdentity(
            output: outputIdentity(id: 42, uid: "audio-keyboard-a"),
            transitionGeneration: 0
        )
        let second = interactionIdentity(
            output: outputIdentity(id: 43, uid: "audio-keyboard-b"),
            transitionGeneration: 1
        )
        var emittedScalars: [Double] = []
        var interaction = VolumeControlInteraction(
            setVolume: { emittedScalars.append($0) },
            finishVolume: {}
        )

        interaction.receiveSystemState(
            identity: first,
            scalar: 0.2,
            canAdjust: true
        )
        interaction.setSliderValue(
            0.6,
            identity: first,
            canAdjust: true
        )
        interaction.receiveSystemState(
            identity: second,
            scalar: 0.3,
            canAdjust: true
        )
        interaction.setSliderValue(
            0.7,
            identity: second,
            canAdjust: true
        )

        XCTAssertEqual(emittedScalars, [0.6, 0.7])
    }

    func testABATransitionAtEqualScalarRequiresFreshBeginEvenWhenBIsCoalesced() {
        let output = outputIdentity(id: 43, uid: "audio-display")
        let before = interactionIdentity(
            output: output,
            transitionGeneration: 0
        )
        // A -> B -> A may publish only the final A state. Its monotonic epoch
        // must still make the interaction identity observably different.
        let after = interactionIdentity(
            output: output,
            transitionGeneration: 2
        )
        var emittedScalars: [Double] = []
        var finishCount = 0
        var interaction = VolumeControlInteraction(
            setVolume: { emittedScalars.append($0) },
            finishVolume: { finishCount += 1 }
        )

        interaction.receiveSystemState(
            identity: before,
            scalar: 0.5,
            canAdjust: true
        )
        interaction.beginEditing()
        interaction.setSliderValue(
            0.8,
            identity: before,
            canAdjust: true
        )
        interaction.receiveSystemState(
            identity: after,
            scalar: 0.5,
            canAdjust: true
        )

        interaction.setSliderValue(
            0.9,
            identity: after,
            canAdjust: true
        )
        interaction.endEditing(identity: after)

        XCTAssertEqual(interaction.value, 0.5, accuracy: 0.000_001)
        XCTAssertFalse(interaction.isEditing)
        XCTAssertEqual(emittedScalars, [0.8])
        XCTAssertEqual(finishCount, 0)

        interaction.beginEditing()
        interaction.setSliderValue(
            0.9,
            identity: after,
            canAdjust: true
        )
        interaction.endEditing(identity: after)

        XCTAssertEqual(emittedScalars, [0.8, 0.9])
        XCTAssertEqual(finishCount, 1)
    }

    func testCapabilityLossAndRecoveryMidDragRequiresFreshBegin() {
        let identity = interactionIdentity(
            output: outputIdentity(id: 44, uid: "audio-capability"),
            transitionGeneration: 0
        )
        var emittedScalars: [Double] = []
        var finishCount = 0
        var interaction = VolumeControlInteraction(
            setVolume: { emittedScalars.append($0) },
            finishVolume: { finishCount += 1 }
        )

        interaction.receiveSystemState(
            identity: identity,
            scalar: 0.5,
            canAdjust: true
        )
        interaction.beginEditing()
        interaction.setSliderValue(
            0.8,
            identity: identity,
            canAdjust: true
        )
        interaction.receiveSystemState(
            identity: identity,
            scalar: 0.5,
            canAdjust: false
        )
        interaction.receiveSystemState(
            identity: identity,
            scalar: 0.5,
            canAdjust: true
        )

        interaction.setSliderValue(
            0.7,
            identity: identity,
            canAdjust: true
        )
        interaction.endEditing(identity: identity)

        XCTAssertEqual(interaction.value, 0.5, accuracy: 0.000_001)
        XCTAssertFalse(interaction.isEditing)
        XCTAssertEqual(emittedScalars, [0.8])
        XCTAssertEqual(finishCount, 0)

        interaction.beginEditing()
        interaction.setSliderValue(
            0.7,
            identity: identity,
            canAdjust: true
        )
        interaction.endEditing(identity: identity)

        XCTAssertEqual(emittedScalars, [0.8, 0.7])
        XCTAssertEqual(finishCount, 1)
    }

    func testScalarUnavailableRecoveryMidDragRequiresFreshBegin() {
        let identity = interactionIdentity(
            output: outputIdentity(id: 45, uid: "audio-scalar"),
            transitionGeneration: 0
        )
        var emittedScalars: [Double] = []
        var finishCount = 0
        var interaction = VolumeControlInteraction(
            setVolume: { emittedScalars.append($0) },
            finishVolume: { finishCount += 1 }
        )

        interaction.receiveSystemState(
            identity: identity,
            scalar: 0.4,
            canAdjust: true
        )
        interaction.beginEditing()
        interaction.setSliderValue(
            0.7,
            identity: identity,
            canAdjust: true
        )
        interaction.receiveSystemState(
            identity: identity,
            scalar: nil,
            canAdjust: false
        )
        interaction.receiveSystemState(
            identity: identity,
            scalar: 0.4,
            canAdjust: true
        )

        interaction.setSliderValue(
            0.6,
            identity: identity,
            canAdjust: true
        )
        interaction.endEditing(identity: identity)

        XCTAssertEqual(emittedScalars, [0.7])
        XCTAssertEqual(finishCount, 0)

        interaction.beginEditing()
        interaction.setSliderValue(
            0.6,
            identity: identity,
            canAdjust: true
        )
        interaction.endEditing(identity: identity)

        XCTAssertEqual(emittedScalars, [0.7, 0.6])
        XCTAssertEqual(finishCount, 1)
    }

    func testPassiveRouteTransitionKeepsKeyboardBindingUsableWithoutBegin() {
        let first = interactionIdentity(
            output: outputIdentity(id: 46, uid: "audio-keyboard-a"),
            transitionGeneration: 0
        )
        let second = interactionIdentity(
            output: outputIdentity(id: 47, uid: "audio-keyboard-b"),
            transitionGeneration: 1
        )
        var emittedScalars: [Double] = []
        var interaction = VolumeControlInteraction(
            setVolume: { emittedScalars.append($0) },
            finishVolume: {}
        )

        interaction.receiveSystemState(
            identity: first,
            scalar: 0.3,
            canAdjust: true
        )
        interaction.receiveSystemState(
            identity: second,
            scalar: 0.3,
            canAdjust: true
        )
        interaction.setSliderValue(
            0.6,
            identity: second,
            canAdjust: true
        )

        XCTAssertEqual(emittedScalars, [0.6])
        XCTAssertFalse(interaction.isEditing)
    }

    func testUnmanagedBindingUpdateDoesNotBlockLaterSystemSynchronization() {
        let identity = interactionIdentity(
            output: outputIdentity(id: 48, uid: "audio-unmanaged"),
            transitionGeneration: 0
        )
        var emittedScalars: [Double] = []
        var finishCount = 0
        var interaction = VolumeControlInteraction(
            setVolume: { emittedScalars.append($0) },
            finishVolume: { finishCount += 1 }
        )

        interaction.receiveSystemState(
            identity: identity,
            scalar: 0.2,
            canAdjust: true
        )
        interaction.setSliderValue(
            0.6,
            identity: identity,
            canAdjust: true
        )
        interaction.receiveSystemState(
            identity: identity,
            scalar: 0.35,
            canAdjust: true
        )
        interaction.endEditing(identity: identity)

        XCTAssertEqual(interaction.value, 0.35, accuracy: 0.000_001)
        XCTAssertFalse(interaction.isEditing)
        XCTAssertEqual(emittedScalars, [0.6])
        XCTAssertEqual(finishCount, 0)
    }

    func testMapperCarriesExternalVolumeTransitionGeneration() {
        let output = AudioOutputDevice(
            id: 49,
            name: "External display",
            uid: "audio-display",
            isCurrent: true
        )
        let state = AudioPanelMapper.volume(
            VolumeStatus(
                scalar: 0.5,
                isMuted: false,
                deviceName: output.name,
                currentDevice: output,
                outputDevices: [output],
                canSetVolume: true,
                canMute: true,
                muteState: .unmuted,
                externalVolumeTransitionGeneration: 17
            ),
            controllerAvailable: true,
            localization: makeEnglishLocalization()
        )

        XCTAssertEqual(state.interactionIdentity.transitionGeneration, 17)
    }

    func testMonitorAdvancesExternalVolumeGenerationAcrossNativeABASameScalar() async {
        let first = AudioOutputDevice(
            id: 51,
            name: "First output",
            uid: "audio-first",
            isCurrent: true
        )
        let second = AudioOutputDevice(
            id: 52,
            name: "Second output",
            uid: "audio-second",
            isCurrent: true
        )
        let sequence = RouteReadingSequence([
            routeReading(device: first, scalar: 0.5),
            routeReading(device: second, scalar: 0.5),
            routeReading(device: first, scalar: 0.5)
        ])
        let monitor = VolumeMonitor(
            statusReader: CoreAudioStatusReader { _ in
                AudioStatusReading(volume: sequence.next(), outputDevices: nil)
            },
            eventMonitor: PassiveVolumeEventMonitor()
        )
        var iterator = monitor.updates.makeAsyncIterator()
        var statuses: [VolumeStatus] = []

        for _ in 0..<3 {
            monitor.refresh()
            guard let status = await iterator.next() else {
                XCTFail("VolumeMonitor finished before publishing all route states")
                monitor.stop()
                return
            }
            statuses.append(status)
        }
        monitor.stop()

        XCTAssertEqual(statuses.map { $0.currentDevice?.id }, [51, 52, 51])
        XCTAssertEqual(statuses.map(\.scalar), [0.5, 0.5, 0.5])
        XCTAssertLessThan(
            statuses[0].externalVolumeTransitionGeneration,
            statuses[1].externalVolumeTransitionGeneration
        )
        XCTAssertLessThan(
            statuses[1].externalVolumeTransitionGeneration,
            statuses[2].externalVolumeTransitionGeneration
        )
    }

    func testFallbackOnlyDescriptionsAndActionableNotConfirmedCopyInEveryLocale() throws {
        let expected: [AppLanguage: LocalizedFallbackCopy] = [
            .english: LocalizedFallbackCopy(
                controlMethodDescription: "If the status panel cannot control this device’s volume, choose BetterDisplay.",
                displayDescription: "Choose the display that corresponds to this audio output.",
                footnote: "Native macOS volume control takes priority. The selected method is used when native control is unavailable.",
                requirements: "If the connection fails, enable CLI access and notification-based integration in BetterDisplay settings.",
                notConfirmed: "The volume change could not be confirmed. Select “Detect Again” and try again."
            ),
            .simplifiedChinese: LocalizedFallbackCopy(
                controlMethodDescription: "如果状态面板的音量控制无法调节此设备，可改用 BetterDisplay。",
                displayDescription: "选择与此音频输出对应的显示器。",
                footnote: "macOS 原生音量控制优先；原生控制不可用时才使用所选方式。",
                requirements: "如果连接失败，请在 BetterDisplay 设置中启用 CLI 访问和基于通知的集成。",
                notConfirmed: "无法确认音量更改。请点按“重新检测”后重试。"
            )
        ]

        XCTAssertEqual(expected.count, AppLanguage.allCases.count)
        for language in AppLanguage.allCases {
            let copy = try XCTUnwrap(
                expected[language],
                "Missing expected copy for \(language.rawValue)"
            )
            let bundle = try XCTUnwrap(Localization.resourceBundle(for: language))
            func value(_ key: LocalizationKey) -> String {
                bundle.localizedString(
                    forKey: key.rawValue,
                    value: nil,
                    table: nil
                )
            }

            XCTAssertEqual(
                value(.settingsAudioExternalVolumeControlMethodDescription),
                copy.controlMethodDescription,
                "\(language.rawValue) control-method copy must suggest BetterDisplay when the status panel cannot control the device"
            )
            XCTAssertEqual(
                value(.settingsAudioExternalVolumeDisplayDescription),
                copy.displayDescription,
                "\(language.rawValue) display copy must describe the linked display for this audio output"
            )
            XCTAssertEqual(
                value(.settingsAudioExternalVolumeFootnote),
                copy.footnote,
                "\(language.rawValue) footnote must keep native macOS volume control as the priority"
            )
            XCTAssertEqual(
                value(.settingsAudioExternalVolumeRequirements),
                copy.requirements,
                "\(language.rawValue) requirements must describe the actionable connection help"
            )
            XCTAssertEqual(
                value(.settingsAudioExternalVolumeStatusNotConfirmed),
                copy.notConfirmed,
                "\(language.rawValue) write-not-confirmed copy must point to Detect Again and retry"
            )
        }
    }

    private func outputIdentity(
        id: AudioDeviceID,
        uid: String
    ) -> PanelAudioDeviceID {
        PanelAudioDeviceID(id: id, uid: uid)
    }

    private func interactionIdentity(
        output: PanelAudioDeviceID,
        transitionGeneration: UInt64
    ) -> VolumeControlInteractionIdentity {
        VolumeControlInteractionIdentity(
            output: output,
            configuration: .default,
            transitionGeneration: transitionGeneration
        )
    }

    private func routeReading(
        device: AudioOutputDevice,
        scalar: Double
    ) -> VolumeReading {
        VolumeReading(
            scalar: scalar,
            isMuted: false,
            deviceName: device.name,
            currentDevice: device,
            canSetVolume: true,
            canMute: true
        )
    }

    private func makeEnglishLocalization() -> Localization {
        let suiteName = "BetterDisplayVolumeUIFixRegressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            TestUserDefaults.removeSuite(named: suiteName)
        }
        return Localization(defaults: defaults, preferredLanguages: ["en"])
    }
}

private struct LocalizedFallbackCopy: Equatable {
    let controlMethodDescription: String
    let displayDescription: String
    let footnote: String
    let requirements: String
    let notConfirmed: String
}

private final class RouteReadingSequence: @unchecked Sendable {
    private let lock = NSLock()
    private let readings: [VolumeReading]
    private var index = 0

    init(_ readings: [VolumeReading]) {
        self.readings = readings
    }

    func next() -> VolumeReading? {
        lock.withLock {
            guard index < readings.count else { return readings.last }
            defer { index += 1 }
            return readings[index]
        }
    }
}

@MainActor
private final class PassiveVolumeEventMonitor: VolumeEventMonitoring {
    func start(
        onDefaultDeviceChange: @escaping @MainActor @Sendable () -> Void,
        onVolumeChange: @escaping @MainActor @Sendable () -> Void
    ) {}

    func reconcile() {}
    func recover() {}
    func stop() {}
}
