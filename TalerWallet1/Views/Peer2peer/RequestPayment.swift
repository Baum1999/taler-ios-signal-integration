/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct RequestPayment: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Request Payment")

    var scopeInfo: ScopeInfo
    @Binding var centsToTransfer: UInt64

    @State private var peerPullCheck: CheckPeerPullCreditResponse? = nil
    @State private var purpose: String = ""
    @State private var expireDays: UInt = 0

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currencyField = CurrencyField(value: $centsToTransfer, currency: scopeInfo.currency)

        VStack(alignment: .leading, spacing: 6) {
            CurrencyInputView(currencyField: currencyField, title: "Amount to receive:")

            HStack {
                let disabled = centsToTransfer == 0

                let deactivateAction = {
                    print("❗️ deactivateAction")
                }

                NavigationLink(destination: LazyView {
                    ReceivePurpose(scopeInfo: scopeInfo,
                             centsToTransfer: centsToTransfer,
                                     purpose: $purpose,
                                  expireDays: $expireDays
                    ) {
                        deactivateAction()
                    }
                }) {
                    Text("title2")
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(navTitle)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {   // make CurrencyField show the keyboard
            DebugViewC.shared.setViewID(VIEW_INVOICE_P2P)
            print("❗️Yikes \(navTitle) onAppear")
        }
        .onDisappear {
            print("❗️Yikes \(navTitle) onDisappear")
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
