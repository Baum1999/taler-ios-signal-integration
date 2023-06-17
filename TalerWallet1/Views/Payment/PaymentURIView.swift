/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import AVFoundation
import SymLog

struct PaymentURIView: View {
    private let symLog = SymLogV()
    var url: URL
    var model: PaymentURIModel?

    @State var detailsForUri: PaymentDetailsForUri? = nil

    func playSound(success: Bool) {
//        let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/PaymentReceived.caf")
        let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/payment_" + (success ? "success.caf"
                                                                                    : "failure.caf"))
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        print(soundID)
        AudioServicesPlaySystemSound(soundID);
    }

    func acceptAction() {
        Task {
            do {
                if let detailsForUri {
                    if let model {
                        let confirmPayResult = try await model.confirmPayM(detailsForUri.proposalId)
                        symLog.log(confirmPayResult as Any)
                        if confirmPayResult.type == "done" {
                            // TODO: Show Hints that Payment was successfull
                            playSound(success: true)
                        } else {
                            // TODO: show error
                            playSound(success: false)
                        }
                    }
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
            dismissTop()
        }
    }

    var body: some View {
        let badURL = "Error in URL: \(url)"
        VStack {
            if let detailsForUri {
                PaymentAcceptView(detailsForUri: detailsForUri, acceptAction: acceptAction)
                    .navigationTitle("Payment")
            } else {
                WithdrawProgressView(message: url.host ?? badURL)
                    .navigationTitle("Contacting Exchange")
            }
        }.task {
            do {
                symLog.log(".task")
                if let model {
                    detailsForUri = try await model.preparePayForUriM(url.absoluteString)
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }
}
