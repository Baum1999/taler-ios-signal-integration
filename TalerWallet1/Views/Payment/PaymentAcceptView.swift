/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import AVFoundation
import SymLog

struct PaymentAcceptView: View {
    private let symLog = SymLogV()
    @ObservedObject var model: PaymentURIModel

    let detailsForAmount: PaymentDetailsForUri

    let navTitle = String(localized: "Accept Payment")
    @State private var confirmPayResult: ConfirmPayResult?

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
                confirmPayResult = try await model.confirmPayM(detailsForAmount.proposalId)
                symLog.log(confirmPayResult as Any)
                if confirmPayResult?.type == "done" {
                    // TODO: Show Hints that Payment was successfull
                    playSound(success: true)
                } else {
                    // TODO: show error
                    playSound(success: false)
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
            dismissTop()
        }
    }

    @State private var disabled = false
    var body: some View {
        Group {
            let raw = detailsForAmount.amountRaw
            let effective = detailsForAmount.amountEffective
            let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
            ThreeAmountsView(topTitle: "Amount to pay:",
                             topAmount: raw, fee: fee,
                             bottomTitle: "Coins to be spent:",
                             bottomAmount: effective,
                             large: true, pending: false, incoming: false,
                             baseURL: detailsForAmount.contractTerms.exchanges.first?.url)
                // TODO: payment: popup with all possible exchanges, check fees
            .safeAreaInset(edge: .bottom) {
                ProminentButton(title: "Accept", action: acceptAction)
                    .padding(.horizontal)
            }
        }
            .navigationTitle(navTitle)
    }
}

//struct PaymentAccept_Previews: PreviewProvider {
//    static var previews: some View {
//        let model: PaymentURIModel =
//        PaymentAcceptView(model: <#PaymentURIModel#>, detailsForAmount: <#PaymentDetailsForUri#>)
//    }
//}
