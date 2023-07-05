/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called by the user tapping "Request Payment" in the balances list
struct RequestPayment: View {
    private let symLog = SymLogV()

    var scopeInfo: ScopeInfo
    @Binding var centsToTransfer: UInt64
    @Binding var summary: String

    @EnvironmentObject private var model: WalletModel

    @State private var peerPullCheck: CheckPeerPullCreditResponse? = nil
    @State private var expireDays: UInt = 0

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = scopeInfo.currency
        let navTitle = String(localized: "Request \(currency)", comment: "Request currency, Dialog Title")
        let currencyField = CurrencyField(value: $centsToTransfer, currency: currency)

        ScrollViewReader { scrollView in
          VStack {
            CurrencyInputView(currencyField: currencyField,
                              title: String(localized: "Amount to receive:"))

            let someCoins = SomeCoins(details: peerPullCheck)
            QuiteSomeCoins(someCoins: someCoins, shouldShowFee: true,
                           currency: currency, amountEffective: peerPullCheck?.amountEffective)

            HStack {
                let disabled = (centsToTransfer == 0) || someCoins.invalid || someCoins.tooMany

                NavigationLink(destination: LazyView {
                    PaymentPurpose(scopeInfo: scopeInfo,
                             centsToTransfer: centsToTransfer,
                                         fee: someCoins.fee,
                                     summary: $summary,
                                  expireDays: $expireDays)
//                        { deactivateAction() }
                }) {
                    Text("Create invoice")
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
            }
            Spacer()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {   // make CurrencyField show the keyboard
            DebugViewC.shared.setViewID(VIEW_INVOICE_P2P)
            symLog.log("❗️Yikes \(navTitle) onAppear")
        }
        .onDisappear {
            symLog.log("❗️Yikes \(navTitle) onDisappear")
        }
        .task(id: centsToTransfer) {
            let amount = Amount.amountFromCents(currency, centsToTransfer)
            do {
                let ppCheck = try await model.checkPeerPullCreditM(amount, exchangeBaseUrl: nil)
                peerPullCheck = ppCheck
                // TODO: set from exchange
//                agePicker.setAges(ages: peerPushCheck?.ageRestrictionOptions)
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                peerPullCheck = nil
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
