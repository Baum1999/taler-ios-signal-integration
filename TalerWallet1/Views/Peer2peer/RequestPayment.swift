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
    let scopeInfo: ScopeInfo
    let cameraAction: () -> Void

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var peerPullCheck: CheckPeerPullCreditResponse? = nil
    @State private var expireDays: UInt = 0
    @State private var buttonSelected = false
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var exchange: Exchange? = nil                                // wg. noFees

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        buttonSelected = true
    }
    private func feeIsNotZero() -> Bool? {
        if let hasNoFees = exchange?.noFees {
            if hasNoFees {
                return nil      // this exchange never has fees
            }
        }
        return peerPullCheck != nil ? true : false
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = amountToTransfer.currencyStr
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let currencySymbol = currencyInfo.specs.altUnitNames?[0] ?? currency
        let navTitle = String(localized: "NavTitle_Request_Currency",
                           defaultValue: "Request \(currencySymbol)",
                                comment: "NavTitle: Request 'currencySymbol'")
        let coinData = CoinData(details: peerPullCheck)
        let _ = symLog.log("currency: \(currency)")
        let inputDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                 currencyInfo: currencyInfo,
                     feeLabel: coinData.feeLabel(currencyInfo),
                 feeIsNotZero: feeIsNotZero(),
                 amountToSend: false,
             amountToTransfer: $amountToTransfer,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        let shortcutDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                 currencyInfo: currencyInfo,
                     feeLabel: nil,
                 feeIsNotZero: feeIsNotZero(),
                 amountToSend: false,
             amountToTransfer: $amountShortcut,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        let disabled = amountToTransfer.isZero || coinData.invalid || coinData.tooMany
        ScrollView { VStack(alignment: .trailing) {
            CurrencyInputView(currencyInfo: currencyInfo,
                                    amount: $amountToTransfer,
                                 available: nil,
                                     title: minimalistic ? String(localized: "Amount:")
                                                         : String(localized: "Amount to request:"),
                            shortcutAction: shortcutAction)
                .padding(.top)
            QuiteSomeCoins(currencyInfo: currencyInfo,
                               currency: currency,
                               coinData: coinData,
                          shouldShowFee: true,           // always true since the requester pays fees
                        amountEffective: peerPullCheck?.amountEffective)
            NavigationLink(destination: inputDestination) { Text("Next") }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                .disabled(disabled)
                .background(NavigationLink(destination: shortcutDestination, isActive: $buttonSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                )
        }.padding(.horizontal) } // ScrollVStack
        .frame(maxWidth: .infinity, alignment: .leading)
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_REQUEST, stack: stack.push())
            symLog.log("❗️ \(navTitle) onAppear")
        }
        .onDisappear {
            symLog.log("❗️ \(navTitle) onDisappear")
        }
        .navigationBarItems(trailing: QRButton(action: cameraAction))
        .task(id: amountToTransfer.value) {
            if exchange == nil {
                if let url = scopeInfo.url {
                    exchange = try? await model.getExchangeByUrl(url: url)
                }
            }
            if amountToTransfer.isZero {
//                fee = EMPTYSTRING
            } else {
//                peerPullCheck = try? await model.checkPeerPullCreditM(amountToTransfer, exchangeBaseUrl: nil)
                let baseURL = exchange?.exchangeBaseUrl
                peerPullCheck = try? await model.checkPeerPullCreditM(baseURL, amount: amountToTransfer,
                                                                      cancellationId: "cancel")
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
