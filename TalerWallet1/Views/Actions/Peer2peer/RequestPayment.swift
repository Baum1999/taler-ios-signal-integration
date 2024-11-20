/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called when tapping [􁉅Request]
struct RequestPayment: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?
    @Binding var amountLastUsed: Amount
    @Binding var summary: String

    @EnvironmentObject private var controller: Controller

    @State private var balanceIndex = 0
    @State private var balance: Balance? = nil      // nil only when balances == []
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used

    @MainActor
    private func viewDidLoad() async {
        if let selectedBalance {
            balance = selectedBalance
            balanceIndex = controller.balances.firstIndex(of: selectedBalance) ?? 0
        } else {
            balanceIndex = 0
            balance = (controller.balances.count > 0) ? controller.balances[0] : nil
        }
    }

    private func navTitle(_ currency: String, _ condition: Bool = false) -> String {
        condition ? String(localized: "NavTitle_Request_Currency)",
                        defaultValue: "Request \(currency)",
                             comment: "NavTitle: Request 'currency'")
                  : String(localized: "NavTitle_Request",
                        defaultValue: "Request",
                             comment: "NavTitle: Request")
    }

    @MainActor
    private func newBalance() async {
        // runs whenever the user changes the exchange via ScopePicker, or on new currencyInfo
        symLog.log("❗️ task \(balanceIndex)")
        if let balance {
            let scopeInfo = balance.scopeInfo
            amountToTransfer.setCurrency(scopeInfo.currency)
            currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
#endif
        let currencySymbol = currencyInfo.symbol
        let navA11y = navTitle(currencyInfo.name)                               // always include currency for a11y
        let navTitle = navTitle(currencySymbol, currencyInfo.hasSymbol)
        let count = controller.balances.count
        let _ = symLog.log("count = \(count)")
        let scrollView = ScrollView {
            if count > 0 {
                ScopePicker(value: $balanceIndex, onlyNonZero: false)
                { index in
                        balanceIndex = index
                        balance = controller.balances[index]
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            RequestPaymentContent(stack: stack.push(),
                                balance: $balance,
                           balanceIndex: $balanceIndex,
                         amountLastUsed: $amountLastUsed,
                       amountToTransfer: $amountToTransfer,
                                summary: $summary)
        } // ScrollView
            .navigationTitle(navTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
            .onAppear {
                DebugViewC.shared.setViewID(VIEW_P2P_REQUEST, stack: stack.push())
                symLog.log("❗️ \(navTitle) onAppear")
            }
            .onDisappear {
                symLog.log("❗️ \(navTitle) onDisappear")
            }
            .task { await viewDidLoad() }
            .task(id: balanceIndex + (1000 * controller.currencyTicker)) { await newBalance() }

        if #available(iOS 16.0, *) {
            if #available(iOS 16.4, *) {
                scrollView.toolbar(.hidden, for: .tabBar)
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                scrollView.toolbar(.hidden, for: .tabBar)
            }
        } else {
            scrollView
        }
    }
}
// MARK: -
struct RequestPaymentContent: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var balance: Balance?
    @Binding var balanceIndex: Int
    @Binding var amountLastUsed: Amount
    @Binding var amountToTransfer: Amount
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
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var amountZero = Amount.zero(currency: EMPTYSTRING)          // needed for isZero
    @State private var exchange: Exchange? = nil                                // wg. noFees

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

    @MainActor
    private func computeFee(_ amount: Amount) async -> ComputeFeeResult? {
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
            let ppCheck = try await model.checkPeerPullCredit(amount, scope: scopeInfo, viewHandles: true)
            let raw = ppCheck.amountRaw
            let effective = ppCheck.amountEffective
            if let fee = fee(raw: raw, effective: effective) {
                feeStr = fee.formatted(scopeInfo, isNegative: true)
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
            symLog.log("❗️ \(error), \(error.localizedDescription)")
            switch error {
                case let walletError as WalletBackendError:
                    switch walletError {
                        case .walletCoreError(let wError):
                            if wError?.code == 7027 {
                                return ComputeFeeResult.insufficient()
                            }
                        default: break
                    }
                default: break
            }
        }
        return nil
    } // computeFee

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if let balance {
            Group { if scopeInfo != nil {
                let coinData = CoinData(details: peerPullCheck)
//                let availableStr = amountAvailable.formatted(currencyInfo, isNegative: false)
//                let amountVoiceOver = amountToTransfer.formatted(currencyInfo, isNegative: false)
                let feeLabel = coinData.feeLabel(scopeInfo, feeZero: String(localized: "No payment fee"),
                                                 isNegative: false)
                let inputDestination = P2PSubjectV(stack: stack.push(),
                                                   scope: scopeInfo,
                                                feeLabel: feeLabel,
                                            feeIsNotZero: feeIsNotZero(),
                                                outgoing: false,
                                        amountToTransfer: $amountToTransfer,
                                                 summary: $summary,
                                              expireDays: $expireDays)
                let shortcutDestination = P2PSubjectV(stack: stack.push(),
                                                      scope: scopeInfo,
                                                   feeLabel: nil,
                                               feeIsNotZero: feeIsNotZero(),
                                                   outgoing: false,
                                           amountToTransfer: $amountShortcut,
                                                    summary: $summary,
                                                 expireDays: $expireDays)
                let actions = Group {
                    NavLink($buttonSelected) { inputDestination }
                    NavLink($shortcutSelected) { shortcutDestination }
                }
                let amountLabel = minimalistic ? String(localized: "Amount:")
                                               : String(localized: "Amount to request:")
                AmountInputV(stack: stack.push(),
                             scope: scopeInfo,
                   amountAvailable: $amountZero,        // incoming needs no available
                       amountLabel: amountLabel,
                  amountToTransfer: $amountToTransfer,
                    amountLastUsed: amountLastUsed,
                           wireFee: nil,
                           summary: $summary,
                    shortcutAction: shortcutAction,
                      buttonAction: buttonAction,
                     feeIsNegative: true,
                        computeFee: computeFee)
                .background(actions)
            } } // if, Group
            .task {
                scopeInfo = balance.scopeInfo
            }
        } else {    // no balance - Yikes
            Text("No balance. There seems to be a problem with the database...")
        }
    } // body
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
