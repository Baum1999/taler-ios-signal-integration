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

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("iconOnly") var iconOnly: Bool = false

    @State private var peerPullCheck: CheckPeerPullCreditResponse? = nil
    @State private var expireDays: UInt = 0
    @State private var buttonSelected = false
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        buttonSelected = true
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
        let someCoins = SomeCoins(details: peerPullCheck)
        let _ = symLog.log("currency: \(currency)")
        let inputDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                     feeLabel: someCoins.feeLabel(currencyInfo),
                 currencyInfo: currencyInfo,
                 amountToSend: false,
             amountToTransfer: $amountToTransfer,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        let shortcutDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                     feeLabel: nil,
                 currencyInfo: currencyInfo,
                 amountToSend: false,
             amountToTransfer: $amountShortcut,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        let disabled = amountToTransfer.isZero || someCoins.invalid || someCoins.tooMany
        ScrollView { VStack(alignment: .trailing) {
            CurrencyInputView(amount: $amountToTransfer,
                           available: nil,
                               title: iconOnly ? String(localized: "Amount:")
                                               : String(localized: "Amount to request:"),
                      shortcutAction: shortcutAction)
                .padding(.top)
            QuiteSomeCoins(someCoins: someCoins,
                       shouldShowFee: true,     // always true since the requester pays fees
                            currency: currency,
                        currencyInfo: currencyInfo,
                     amountEffective: peerPullCheck?.amountEffective)
            NavigationLink(destination: inputDestination) { Text("Next") }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
                .background(NavigationLink(destination: shortcutDestination, isActive: $buttonSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                )
        } } // ScrollVStack
        .frame(maxWidth: .infinity, alignment: .leading)
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
        .padding(.horizontal)   // Lists do this automatically, but this is a VStack
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_REQUEST, stack: stack.push())
            symLog.log("❗️ \(navTitle) onAppear")
        }
        .onDisappear {
            symLog.log("❗️ \(navTitle) onDisappear")
        }
        .task(id: amountToTransfer.value) {
            if amountToTransfer.isZero {
//                fee = EMPTYSTRING
            } else {
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
