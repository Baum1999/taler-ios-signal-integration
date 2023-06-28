/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import AVFoundation

func playSound(_ number: Int) {
    let sound = (number == 0) ? "payment_failure" :
                (number == 1) ? "payment_success" : "PaymentReceived"
    let fileURL = URL(fileURLWithPath: "/System/Library/Audio/UISounds/"
                                        + sound + ".caf")
    var soundID: SystemSoundID = 0
    AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
    AudioServicesPlaySystemSound(soundID);
}
