/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import AVFoundation

extension Controller {

    func playSound(_ number: Int) {
        var soundID: SystemSoundID = 0
        if number < 999 {
            let sound = (number == 0) ? "payment_failure" :
            (number == 1) ? "payment_success" : "PaymentReceived"
            let fileURL = URL(fileURLWithPath: "/System/Library/Audio/UISounds/"
                              + sound + ".caf")
            AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
        } else {
            soundID = UInt32(number)
        }
        if playSounds {
            AudioServicesPlaySystemSound(soundID);
        }
    }
}
