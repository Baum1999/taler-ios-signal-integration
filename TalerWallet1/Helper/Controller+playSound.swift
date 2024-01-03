/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import AVFoundation
import UIKit

extension Controller {

    @MainActor
    func hapticNotification(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
        if useHaptics {
            UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
        }
    }

    @MainActor
    func hapticFeedback(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }


    /// 0 = failure, 1 = received, 2 = sent
    @MainActor func playSound(_ number: Int) {
        let sysVolume = AVAudioSession.sharedInstance().outputVolume
        let volume = sysVolume < 0.16 ? 2.5     // too bad we cannot make it louder
                   : sysVolume < 0.21 ? 1.5     // nope, doesn't work
                   : sysVolume < 0.26 ? 1.0     // this is full volume...
                   : sysVolume < 0.31 ? 0.9     // and
//                 : sysVolume < 0.36 ?
                   : sysVolume < 0.41 ? 0.8     // we
//                 : sysVolume < 0.46 ?
                   : sysVolume < 0.51 ? 0.7     // must
                   : sysVolume < 0.56 ? 0.6     // reduce
//                 : sysVolume < 0.61 ?
                   : sysVolume < 0.66 ? 0.5     // it,
                   : sysVolume < 0.71 ? 0.4     // or
                   : sysVolume < 0.76 ? 0.3     // it'll
                   : sysVolume < 0.81 ? 0.2     // play
                   : sysVolume < 0.86 ? 0.15    // way
                   : sysVolume < 0.91 ? 0.10    // too
                                      : 0.07    // loud!
//        logger.log("❗️sys:\(sysVolume)  vol:\(volume)")

        var soundID: SystemSoundID = 0
        if number > 9 {
            soundID = UInt32(number)
        } else {
            let sound = (number == 0) ? "payment_failure" :
                        (number == 1) ? "payment_success"
                                      : "PaymentReceived"
            let fileURL = URL(fileURLWithPath: "/System/Library/Audio/UISounds/"
                              + sound + ".caf")
            AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
            logger.log("\(sound, privacy: .public) \(soundID)")
        }
        if number == 0 || number > 9 || playSoundsI < 0 {
            AudioServicesPlaySystemSound(soundID);
        } else if playSoundsI > 0 && playSoundsB {
            if let url = Bundle.main.url(forResource: (number == 1) ? "payment_sent"
                                                                    : "payment_received",
                                       withExtension: "m4a") {
                player.removeAllItems()
                player.insert(AVPlayerItem(url: url), after: nil)
                logger.log("\(url, privacy: .public)")
                player.play()
                player.volume = Float(volume)
            } else {
                AudioServicesPlaySystemSound(soundID);
            }
        }
        hapticNotification(number == 0 ? .error : .success)
    }
}
