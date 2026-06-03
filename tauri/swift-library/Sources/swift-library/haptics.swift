import AppKit
import CoreHaptics

public func triggerTrackpadHaptic(intensity: Double, sharpness: Double) {
    if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            try engine.start()

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness)),
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)

            engine.stoppedHandler = { reason in
                _ = engine
            }

            try player.start(atTime: 0)
            return
        } catch {
        }
    }

    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
}
