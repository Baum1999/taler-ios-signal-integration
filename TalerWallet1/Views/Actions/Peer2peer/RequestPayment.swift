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
    let balances: [Balance]
    @Binding var selectedBalance: Balance?

    @Binding var amountLastUsed: Amount
    @Binding var summary: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var peerPullCheck: CheckPeerPullCreditResponse? = nil
    @State private var expireDays: UInt = 0
//    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var buttonSelected = false
    @State private var shortcutSelected = false
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var amountZero = Amount.zero(currency: EMPTYSTRING)          // needed for isZero
    @State private var exchange: Exchange? = nil                                // wg. noFees
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var currencyName: String = UNKNOWN
    @State private var currencySymbol: String = UNKNOWN
    @State private var scopeInfo: ScopeInfo = ScopeInfo.zero()

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        shortcutSelected = true
    }
    private func buttonAction() { buttonSelected = true }

    private func feeLabel(_ feeString: String) -> String {
        feeString.count > 0 ? String(localized: "- \(feeString) fee")
        : EMPTYSTRING
    }

    private func fee(raw: Amount, effective: Amount) -> Amount? {
        do {     // Incoming: fee = raw - effective
            let fee = try raw - effective
            return fee
        } catch {}
        return nil
    }

    private func feeIsNotZero() -> Bool? {
        if let hasNoFees = exchange?.noFees {
            if hasNoFees {
                return nil      // this exchange never has fees
            }
        }
        return peerPullCheck != nil ? true : false
    }

    private func computeFeeRequest(_ amount: Amount) async -> ComputeFeeResult? {
        if exchange == nil {
            if let url = scopeInfo.url {
                exchange = try? await model.getExchangeByUrl(url: url)
            }
        }
        if amount.isZero {
            return ComputeFeeResult.zero()
        }
        do {
            let baseURL = exchange?.exchangeBaseUrl
            let ppCheck = try await model.checkPeerPullCreditM(amount, scope: scopeInfo, viewHandles: true)
            let raw = ppCheck.amountRaw
            let effective = ppCheck.amountEffective
            if let fee = fee(raw: raw, effective: effective) {
                feeStr = fee.formatted(currencyInfo, isNegative: true)
                symLog.log("Fee = \(feeStr)")

                peerPullCheck = ppCheck
                return ComputeFeeResult(insufficient: false,
                                           feeAmount: fee,
                                              feeStr: feeLabel(feeStr),
                                            numCoins: ppCheck.numCoins)
            } else {
                peerPullCheck = nil
            }
        } catch {
            // handle cancel, errors
            symLog.log("❗️ \(error)")
        }
        return nil
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = amountToTransfer.currencyStr
//        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let currencySymbol = currencyInfo.altUnitSymbol ?? currency
        let navTitle = String(localized: "NavTitle_Request_Currency",
                           defaultValue: "Request \(currencySymbol)",
                                comment: "NavTitle: Request 'currencySymbol'")
        let coinData = CoinData(details: peerPullCheck)
        let _ = symLog.log("currency: \(currency)")
        let amountVoiceOver = amountToTransfer.formatted(currencyInfo, isNegative: false)

        let inputDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                        scope: scopeInfo,
                 currencyInfo: $currencyInfo,
                     feeLabel: coinData.feeLabel(currencyInfo,
                                         feeZero: String(localized: "No payment fee"),
                                      isNegative: false),
                 feeIsNotZero: feeIsNotZero(),
                     outgoing: false,
             amountToTransfer: $amountToTransfer,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        let shortcutDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                        scope: scopeInfo,
                 currencyInfo: $currencyInfo,
                     feeLabel: nil,
                 feeIsNotZero: feeIsNotZero(),
                     outgoing: false,
             amountToTransfer: $amountShortcut,
                      summary: $summary,
                   expireDays: $expireDays)
        }

        ScrollView {
            let amountLabel = minimalistic ? String(localized: "Amount:")
                                           : String(localized: "Amount to request:")
            AmountInputV(stack: stack.push(),
                  currencyInfo: $currencyInfo,
               amountAvailable: $amountZero,
                   amountLabel: amountLabel,
              amountToTransfer: $amountToTransfer,
                amountLastUsed: amountLastUsed,
                       wireFee: nil,
                       summary: $summary,
                shortcutAction: shortcutAction,
                  buttonAction: buttonAction,
                 feeIsNegative: true,
                    computeFee: computeFeeRequest)
            .background(NavigationLink(destination: shortcutDestination, isActive: $shortcutSelected)
                        { EmptyView() }.frame(width: 0).opacity(0).hidden()
            ) // shortcutDestination
            .background(NavigationLink(destination: inputDestination, isActive: $buttonSelected)
                        { EmptyView() }.frame(width: 0).opacity(0).hidden()
            ) // inputDestination
        } // ScrollView
        .frame(maxWidth: .infinity, alignment: .leading)
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_REQUEST, stack: stack.push())
            // if we set >> controller.frontendState = 1 << here, then becomeFirstResponder won't work!
            symLog.log("❗️ \(navTitle) onAppear")
        }
        .onDisappear {
            symLog.log("❗️ \(navTitle) onDisappear")
        }
//        .task(id: amountToTransfer.value) {
//            if exchange == nil {
//                if let url = scopeInfo.url {
//                    exchange = try? await model.getExchangeByUrl(url: url)
//                }
//            }
//            if amountToTransfer.isZero {
// //               fee = EMPTYSTRING
//            } else {
//                let baseURL = exchange?.exchangeBaseUrl
// //               peerPullCheck = try? await model.checkPeerPullCreditM(amountToTransfer, exchangeBaseUrl: nil)
//                peerPullCheck = try? await model.checkPeerPullCreditM(baseURL, amount: amountToTransfer)
//            }
//        }
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
