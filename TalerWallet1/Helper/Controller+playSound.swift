/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import AVFoundation

extension Controller {

    /// 0 = failure, 1 = received, 2 = sent
    func playSound(_ number: Int) {
        var soundID: SystemSoundID = 0
        if number > 9 {
            soundID = UInt32(number)
        } else {
            let sound = (number == 0) ? "payment_failure" :
                        (number == 1) ? "payment_success" : "PaymentReceived"
            let fileURL = URL(fileURLWithPath: "/System/Library/Audio/UISounds/"
                              + sound + ".caf")
            AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
            logger.log("\(sound, privacy: .public) \(soundID)")
        }
        if number == 0 || number > 9 || playSounds < 0 {
            AudioServicesPlaySystemSound(soundID);
        } else if playSounds > 0 {
            if let url = Bundle.main.url(forResource: (number == 1) ? "payment_received"
                                                                    : "payment_sent",
                                         withExtension: "m4a") {
                player.removeAllItems()
                player.insert(AVPlayerItem(url: url), after: nil)
                logger.log("\(url, privacy: .public) \(soundID)")
                player.play()
            } else {
                AudioServicesPlaySystemSound(soundID);
            }
        }
    }
}
