/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Called when tapping "Request Payment" in the balances list
struct RequestPayment: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    @Binding var amountToTransfer: Amount
    @Binding var summary: String

    @EnvironmentObject private var model: WalletModel
    @AppStorage("iconOnly") var iconOnly: Bool = false

    @State private var peerPullCheck: CheckPeerPullCreditResponse? = nil
    @State private var expireDays: UInt = 0

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = amountToTransfer.currencyStr
        let navTitle = String(localized: "Request Money", comment: "Dialog Title")

        ScrollView { VStack {
            CurrencyInputView(amount: $amountToTransfer,
                               title: iconOnly ? String(localized: "How much:")
                                               : String(localized: "Amount to request:"),
                       shortcutLabel: String(localized: "Request", comment: "VoiceOver: Request $50,$25,$10,$5 shortcut buttons"))

            let someCoins = SomeCoins(details: peerPullCheck)
            QuiteSomeCoins(someCoins: someCoins,
                       shouldShowFee: true,     // always true since the requester pays fees
                            currency: currency,
                     amountEffective: peerPullCheck?.amountEffective)

            HStack {
                let disabled = amountToTransfer.isZero || someCoins.invalid || someCoins.tooMany

                NavigationLink(destination: LazyView {
                    RequestPurpose(stack: stack.push(),
                        amountToTransfer: amountToTransfer,
                                     fee: someCoins.fee,
                                 summary: $summary,
                              expireDays: $expireDays)
//                        { deactivateAction() }
                }) {
                    Text("Request \(amountToTransfer.readableDescription)")     // TODO: formatter
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
            }
            Spacer()
        } }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {   // make CurrencyField show the keyboard
            DebugViewC.shared.setViewID(VIEW_REQUEST_P2P, stack: stack.push())
            symLog.log("❗️Yikes \(navTitle) onAppear")
        }
        .onDisappear {
            symLog.log("❗️Yikes \(navTitle) onDisappear")
        }
        .task(id: amountToTransfer.value) {
            if !amountToTransfer.isZero {
                do {
                    let ppCheck = try await model.checkPeerPullCreditM(amountToTransfer, exchangeBaseUrl: nil)
                    peerPullCheck = ppCheck     // redraw
                    // TODO: set from exchange
//                  agePicker.setAges(ages: peerPushCheck?.ageRestrictionOptions)
                } catch {    // TODO: error
                    symLog.log(error.localizedDescription)
                    peerPullCheck = nil
                }
            }
        }
    }
}
// MARK: -
#if DEBUG
//struct ReceiveAmount_Previews: PreviewProvider {
//    static var scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, exchangeBaseUrl: DEMOEXCHANGE, currency: LONGCURRENCY)
//    static var previews: some View {
//        let amount = Amount(currency: LONGCURRENCY, integer: 10, fraction: 0)
//        RequestPayment(exchangeBaseUrl: DEMOEXCHANGE, currency: LONGCURRENCY)
//    }
//}
#endif
