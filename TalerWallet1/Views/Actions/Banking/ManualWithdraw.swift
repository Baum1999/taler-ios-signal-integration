/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called when tapping [􁾭Withdraw]
// or from WithdrawExchangeScan after a withdraw-exchange QR was scanned
struct ManualWithdraw: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let url: URL?
    // when Action is tapped while in currency TransactionList…
    let selectedBalance: Balance?   // …then use THIS balance, otherwise show picker
    @Binding var amountLastUsed: Amount
    @Binding var amountToTransfer: Amount           // Update currency when used
    let exchange: Exchange?                         // only for withdraw-exchange
    let maySwitchCurrencies: Bool                   // not for withdraw-exchange
    let isSheet: Bool                               // true: WithdrawExchangeScan

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var balanceIndex = 0
    @State private var balance: Balance? = nil      // nil only when balances == []
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)

    private func viewDidLoad() async {
        if let exchange {
            currencyInfo = controller.info(for: exchange.scopeInfo, controller.currencyTicker)
            return
        } else if let selectedBalance {
            balance = selectedBalance
            balanceIndex = controller.balances.firstIndex(of: selectedBalance) ?? 0
        } else {
            balanceIndex = 0
            balance = controller.balances.isEmpty ? nil : controller.balances[0]
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

    func updateCurrInfo(_ scope: ScopeInfo) {
        symLog.log("balance = \(scope.url)")
        amountToTransfer.setCurrency(scope.currency)
        currencyInfo = controller.info(for: scope, controller.currencyTicker)
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
#endif
        let currencySymbol = currencyInfo.symbol
        let navA11y = navTitle(currencyInfo.name)                               // always include currency for a11y
        let navTitle = navTitle(currencySymbol, currencyInfo.hasSymbol)
        let count = controller.balances.count
        let scrollView = ScrollView {
            if maySwitchCurrencies && count > 1 {
                ScopePicker(stack: stack.push(),
                            value: $balanceIndex,
                      onlyNonZero: false)
                { index in
                    balanceIndex = index
                    balance = controller.balances[index]
                    if let balance {
                        updateCurrInfo(balance.scopeInfo)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }   // TODO: else show static text?
            if let scope = balance?.scopeInfo ?? exchange?.scopeInfo {
                let _ = symLog.log("exchange = \(exchange?.exchangeBaseUrl), scope = \(scope.url), amountToTransfer = \(amountToTransfer.currencyStr)")
                ManualWithdrawContent(stack: stack.push(),
                                        url: url,
                                      scope: scope,
                             amountLastUsed: $amountLastUsed,
                           amountToTransfer: $amountToTransfer,
                                   exchange: exchange)
            } else {  // should never happen, we either have an exchange or a balance
                ErrorView(stack.push(), title: navTitle,
                        message: String(localized: "No scope"), copyable: true)
            }
        } // ScrollView
            .navigationTitle(navTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FullBackground())
            .onAppear {
                if isSheet {
                    DebugViewC.shared.setSheetID(SHEET_WITHDRAW_EXCHANGE,       // 135 WithdrawExchangeScan
                                                 stack: stack.push())
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
            .task(id: controller.currencyTicker) {
                // runs whenever a new currencyInfo is available
                symLog.log("❗️ task \(controller.currencyTicker)")
                let scopeInfo = maySwitchCurrencies ? balance?.scopeInfo
                                                    : exchange?.scopeInfo
                if let scopeInfo {
                    updateCurrInfo(scopeInfo)
                }
            }

        if #available(iOS 16.4, *) {
            scrollView.toolbar(.hidden, for: .tabBar)
                .scrollBounceBehavior(.basedOnSize)
        } else {
            scrollView
        }
    }
}
// MARK: -
struct ManualWithdrawContent: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let url: URL?
    let scope: ScopeInfo
    @Binding var amountLastUsed: Amount
    @Binding var amountToTransfer: Amount
    let exchange: Exchange?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var detailsForAmount: WithdrawalDetailsForAmount? = nil
    @State private var loadError: Error? = nil
//    @State var ageMenuList: [Int] = []
//    @State var selectedAge = 0
    @State private var tosAccepted = false

    @MainActor
    private func reloadExchange(_ baseURL: String) async {
        symLog.log("getExchangeByUrl(\(baseURL))")
        let exchange = try? await model.getExchangeByUrl(url: baseURL)
        if let tosStatus = exchange?.tosStatus {
            tosAccepted = (tosStatus == .accepted)
                       || (tosStatus == .missingTos)
        } else {
            tosAccepted = false
        }
    }

    @MainActor
    private func getWithdrawalDetailsForAmount(_ amount: Amount, _ reload: Bool = false) async {
        do {
            let details = try await model.getWithdrawalDetailsForAmount(amount,
                                                                baseUrl: nil,
                                                                  scope: scope,
                                                            viewHandles: true)
            if reload {
                await reloadExchange(details.exchangeBaseUrl)
            }
            detailsForAmount = details
            loadError = nil
//          agePicker.setAges(ages: detailsForAmount?.ageRestrictionOptions)
        } catch WalletBackendError.walletCoreError(let walletBackendResponseError) {
            symLog.log(walletBackendResponseError?.hint)
                // TODO: ignore WALLET_CORE_REQUEST_CANCELLED but handle all others
                // Passing non-nil to clientCancellationId will throw WALLET_CORE_REQUEST_CANCELLED
                // when calling getWithdrawalDetailsForAmount again before the last call returned.
                // Since amountToTransfer changed and we don't need the old fee anymore, we just
                // ignore it and do nothing.
            // especially DON'T set detailsForAmount to nil
            if detailsForAmount == nil,
               walletBackendResponseError?.code != 7036 {       // WALLET_CORE_REQUEST_CANCELLED
                // nothing to show yet, so we would spin forever - show the error instead
                loadError = WalletBackendError.walletCoreError(walletBackendResponseError)
            }
        } catch {
            symLog.log(error.localizedDescription)
            detailsForAmount = nil
            loadError = error
        }
    }

    @MainActor
    private func computeFee(_ amount: Amount) async -> ComputeFeeResult? {
        if amount.isZero {
            return ComputeFeeResult.zero()
        }
        await getWithdrawalDetailsForAmount(amount)
        // TODO: actually compute the fee
        return nil
    } // computeFee

    @MainActor
    private func viewDidLoad2() async {
        // neues scope wenn balance geändert wird?
        await getWithdrawalDetailsForAmount(amountToTransfer, true)
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
            ScrollView {
                let coinData = CoinData(details: detailsForAmount)
                let currency = detailsForAmount.scopeInfo.currency
                let baseURL = detailsForAmount.exchangeBaseUrl
//              let agePicker = AgePicker(ageMenuList: $ageMenuList, selectedAge: $selectedAge)
//              let restrictAge: Int? = (selectedAge == 0) ? nil
//                                                         : selectedAge
//  let _ = print(selectedAge, restrictAge)
                let destination = ManualWithdrawDone(stack: stack.push(),
//                                                     scope: detailsForAmount.scopeInfo,
                                                       url: url,
                                                   baseURL: baseURL,
                                          amountToTransfer: amountToTransfer)
//                                             restrictAge: restrictAge)
                let disabled = amountToTransfer.isZero || coinData.invalid || coinData.tooMany

                if tosAccepted {    // Von der Bank abzuhebender Betrag
                    let a11yLabel = String(localized: "Amount to withdraw from bank", comment: "a11y, no abbreviations")
                    let title = String(localized: "Amount to withdraw from bank:")
                    let amountLabel = minimalistic ? String(localized: "Amount:")
                                                   : title
                    CurrencyInputView(scope: scope,
                                     amount: $amountToTransfer,
                             amountLastUsed: amountLastUsed,
                                  available: nil,               // enable shortcuts always
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
                        exchangeBaseUrl: scope.url ?? baseURL,
                                 viewID: VIEW_WITHDRAW_TOS,   // 31 WithdrawTOSView   TODO: might be withdraw-exchange
                                    p2p: false,
                           acceptAction: nil)
                    .padding(.top)
                }
            } // ScrollView
                .padding(.horizontal)
//                .ignoresSafeArea(.keyboard, edges: .bottom)
                .task(id: amountToTransfer.currencyStr) {
                    await getWithdrawalDetailsForAmount(amountToTransfer, true)
                }
        } else if let loadError {
            // "OK" clears the error, which brings back the LoadingView and thus retries
            ErrorView(stack.push(), error: loadError, devMode: developerMode) {
                self.loadError = nil
            }
        } else {
            LoadingView(stack: stack.push(), scopeInfo: scope, message: nil)
                .task { await viewDidLoad2() }
        }
    }
}
