/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called when tapping [􁾭Withdraw]
// or from WithdrawExchangeV after a withdraw-exchange QR was scanned
struct ManualWithdraw: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?
    @Binding var amountLastUsed: Amount
    @Binding var amountToTransfer: Amount
    @Binding var exchange: Exchange?           // only for withdraw-exchange
    let isSheet: Bool

    @EnvironmentObject private var controller: Controller

    @State private var balanceIndex = 0
    @State private var balance: Balance? = nil      // nil only when balances == []
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
//    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used

    private func viewDidLoad() async {
        if let exchange {
            currencyInfo = controller.info(for: exchange.scopeInfo, controller.currencyTicker)
            return
        } else if let selectedBalance {
            balance = selectedBalance
            balanceIndex = controller.balances.firstIndex(of: selectedBalance) ?? 0
        } else {
            balanceIndex = 0
            balance = (controller.balances.count > 0) ? controller.balances[0] : nil
        }
        if let balance {
            currencyInfo = controller.info(for: balance.scopeInfo, controller.currencyTicker)
        }
    }
    func navTitle(_ currency: String, _ condition: Bool = false) -> String {
        condition ? String(localized: "NavTitle_Withdraw_Currency)",
                        defaultValue: "Withdraw \(currency)",
                             comment: "NavTitle: Withdraw 'currency'")
                  : String(localized: "NavTitle_Withdraw",
                        defaultValue: "Withdraw",
                             comment: "NavTitle: Withdraw")
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
            if let exchange {
                ManualWithdrawContent(stack: stack.push(),
                                      scope: exchange.scopeInfo,
                             amountLastUsed: $amountLastUsed,
                           amountToTransfer: $amountToTransfer,
                                   exchange: $exchange)
            } else {
                if count > 0 {
                    ScopePicker(value: $balanceIndex, onlyNonZero: false)
                    { index in
                        balanceIndex = index
                        balance = controller.balances[index]
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
                if let balance {
                    ManualWithdrawContent(stack: stack.push(),
                                          scope: balance.scopeInfo,
                                 amountLastUsed: $amountLastUsed,
                               amountToTransfer: $amountToTransfer,
                                       exchange: $exchange)
                }
            }
        } // ScrollView
            .navigationTitle(navTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
            .onAppear {
                if isSheet {
                    DebugViewC.shared.setSheetID(SHEET_WITHDRAW_ACCEPT)         // 132 WithdrawAcceptView
                } else {
                    DebugViewC.shared.setViewID(VIEW_WITHDRAWAL,                // 30 WithdrawAmount
                                                stack: stack.push())
                }
                symLog.log("❗️ \(navTitle) onAppear")
            }
            .onDisappear {
                symLog.log("❗️ \(navTitle) onDisappear")
            }
            .task { await viewDidLoad() }
            .task(id: balanceIndex + (1000 * controller.currencyTicker)) {
                // runs whenever the user changes the exchange via ScopePicker, or on new currencyInfo
                symLog.log("❗️ task \(balanceIndex)")
                if let exchange {
                    let scopeInfo = exchange.scopeInfo
                    amountToTransfer.setCurrency(scopeInfo.currency)
                    currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
                } else if let balance {
                    let scopeInfo = balance.scopeInfo
                    amountToTransfer.setCurrency(scopeInfo.currency)
                    currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
                }
            }

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
struct ManualWithdrawContent: View {
    private let symLog = SymLogV()
    let stack: CallStack
    let scope: ScopeInfo
    @Binding var amountLastUsed: Amount
    @Binding var amountToTransfer: Amount
    @Binding var exchange: Exchange?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var detailsForAmount: WithdrawalDetailsForAmount? = nil
//    @State var ageMenuList: [Int] = []
//    @State var selectedAge = 0

    private func exchangeVia(_ baseURL: String?) -> String? {
        if let baseURL {
            return String(localized: "via \(baseURL.trimURL)", comment: "currency/exchange chooser")
        }
        return nil
    }

    @MainActor
    private func computeFee(_ amount: Amount) async -> ComputeFeeResult? {
        if amount.isZero {
            return ComputeFeeResult.zero()
        }
        do {
            let details = try await model.getWithdrawalDetailsForAmount(amount, baseUrl: nil, scope: scope,
                                                            viewHandles: true)
            detailsForAmount = details
//          agePicker.setAges(ages: detailsForAmount?.ageRestrictionOptions)
        } catch WalletBackendError.walletCoreError(let walletBackendResponseError) {
            symLog.log(walletBackendResponseError?.hint)
                // TODO: ignore WALLET_CORE_REQUEST_CANCELLED but handle all others
                // Passing non-nil to clientCancellationId will throw WALLET_CORE_REQUEST_CANCELLED
                // when calling getWithdrawalDetailsForAmount again before the last call returned.
                // Since amountToTransfer changed and we don't need the old fee anymore, we just
                // ignore it and do nothing.
        } catch {
            symLog.log(error.localizedDescription)
            detailsForAmount = nil
            }
        return nil
    } // computeFee

    @MainActor
    private func reloadExchange(_ baseURL: String) async {
        if exchange == nil || exchange?.tosStatus != .accepted {
            symLog.log("getExchangeByUrl(\(baseURL))")
            exchange = try? await model.getExchangeByUrl(url: baseURL)
        }
    }
    @MainActor
    private func viewDidLoad2() async {
        // neues scope wenn balance geändert wird?
        let details = try? await model.getWithdrawalDetailsForAmount(amountToTransfer, baseUrl: nil, scope: scope,
                                                         viewHandles: true)
        if let details {
            detailsForAmount = details
        }
    }

    private func withdrawButtonTitle(_ currency: String) -> String {
        switch currency {
            case CHF_4217:
                String(localized: "WITHDRAW_CONFIRM_BUTTONTITLE_CHF", defaultValue: "Confirm Withdrawal")
            case EUR_4217:
                String(localized: "WITHDRAW_CONFIRM_BUTTONTITLE_EUR", defaultValue: "Confirm Withdrawal")
            default:
                String(localized: "WITHDRAW_CONFIRM_BUTTONTITLE", defaultValue: "Confirm Withdrawal")
        }
    }
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif

        if let detailsForAmount {
            Group {
                let coinData = CoinData(details: detailsForAmount)
                let currency = detailsForAmount.scopeInfo.currency
                let baseURL = detailsForAmount.exchangeBaseUrl
//              let agePicker = AgePicker(ageMenuList: $ageMenuList, selectedAge: $selectedAge)
//              let restrictAge: Int? = (selectedAge == 0) ? nil
//                                                         : selectedAge
//  let _ = print(selectedAge, restrictAge)
                let destination = ManualWithdrawDone(stack: stack.push(),
//                                                     scope: detailsForAmount.scopeInfo,
                                                   baseURL: baseURL,
                                          amountToTransfer: amountToTransfer)
//                                             restrictAge: restrictAge)
                let disabled = amountToTransfer.isZero || coinData.invalid || coinData.tooMany
                let tosAccepted = (exchange?.tosStatus == .accepted) ?? false

                if tosAccepted {
                    let a11yLabel = String(localized: "Amount to withdraw:", comment: "accessibility, no abbreviations")
                    let amountLabel = minimalistic ? String(localized: "Amount:")
                                                   : a11yLabel
                    CurrencyInputView(scope: scope,
                                     amount: $amountToTransfer,
                             amountLastUsed: amountLastUsed,
                                  available: nil,
                                      title: amountLabel,
                                  a11yTitle: a11yLabel,
                             shortcutAction: nil)
                        .padding(.top)
                        .task(id: amountToTransfer.value) { // re-run this whenever amountToTransfer changes
                            await computeFee(amountToTransfer)
                        }
                    QuiteSomeCoins(scope: scope,
                                coinData: coinData,
                           shouldShowFee: true,           // TODO: set to false if we never charge withdrawal fees
                           feeIsNegative: true)
//                  agePicker
                    NavigationLink(destination: destination) {                  // VIEW_WITHDRAW_ACCEPT
                        Text(withdrawButtonTitle(currency))
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                    .disabled(disabled)
                    .padding(.top)
                } else {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: baseURL,
                                 viewID: VIEW_WITHDRAW_TOS,   // 31 WithdrawTOSView   TODO: YIKES might be withdraw-exchange
                                    p2p: false,
                           acceptAction: nil)
                    .padding(.top)
                }
            } // Group
                .padding(.horizontal)
                .task { await reloadExchange(detailsForAmount.exchangeBaseUrl) }
        } else {
            LoadingView(scopeInfo: scope, message: nil)
                .task { await viewDidLoad2() }
        }
    }
}
// MARK: -
#if DEBUG
//struct ManualWithdraw_Previews: PreviewProvider {
//    struct StateContainer : View {
//        @State private var amountToPreview = Amount(currency: LONGCURRENCY, cent: 510)
//        @State private var exchange: Exchange? = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
//                                                                scopeInfo: ScopeInfo(type: .exchange, currency: LONGCURRENCY),
//                                                                paytoUris: [],
//                                                                tosStatus: .accepted,
//                                                      exchangeEntryStatus: .ephemeral,
//                                                     exchangeUpdateStatus: .ready,
//                                                    ageRestrictionOptions: [])
//
//        var body: some View {
//            ManualWithdraw(stack: CallStack("Preview"), isSheet: false,
//                       scopeInfo: <#ScopeInfo?#>,
//                 exchangeBaseUrl: DEMOEXCHANGE,
//                        exchange: $exchange,
//                amountToTransfer: $amountToPreview)
//        }
//    }
//
//    static var previews: some View {
//        StateContainer()
//    }
//}
#endif
