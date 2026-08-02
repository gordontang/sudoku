import AudioToolbox
import UIKit

/// One feedback layer: each event plays its haptic and sound together,
/// each gated by its own setting.
@MainActor
enum Haptics {
    static func light() {
        if AppSettings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        SoundEffects.placement()
    }

    static func warning() {
        if AppSettings.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        SoundEffects.error()
    }

    static func success() {
        if AppSettings.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        SoundEffects.success()
    }
}

@MainActor
enum SoundEffects {
    static func placement() { play(1104) } // keyboard tock
    static func error() { play(1053) }
    static func success() { play(1025) }

    private static func play(_ id: SystemSoundID) {
        guard AppSettings.soundEffects else { return }
        AudioServicesPlaySystemSound(id)
    }
}
