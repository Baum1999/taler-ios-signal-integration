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

// Called when tapping [􁾭Withdraw]
// or from WithdrawExchangeV after a withdraw-exchange QR was scanned
struct ManualWithdraw: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?
    @Binding var amountLastUsed: Amount
    let isSheet: Bool

    @EnvironmentObject private var controller: Controller

    @State private var balanceIndex = 0
    @State private var balance: Balance? = nil      // nil only when balances == []
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)

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
        let navA11y = navTitle(currencyInfo.name)
        let navTitle = navTitle(currencySymbol, currencyInfo.hasSymbol)
        let count = controller.balances.count
        let _ = symLog.log("count = \(count)")
        let scrollView = ScrollView {
            if count > 0 {
                ScopePicker(value: $balanceIndex,
                      onlyNonZero: false)
                { index in
                    balanceIndex = index
                    balance = controller.balances[index]
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            ManualWithdrawContent(stack: stack.push(),
                           currencyInfo: $currencyInfo,
                                balance: $balance,
                           balanceIndex: $balanceIndex,
                         amountLastUsed: $amountLastUsed)
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
            .task {
                if let selectedBalance {
                    balance = selectedBalance
                    balanceIndex = controller.balances.firstIndex(of: selectedBalance) ?? 0
                } else {
                    balanceIndex = 0
                    balance = (count > 0) ? controller.balances[0] : nil
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
    @Binding var currencyInfo: CurrencyInfo
    @Binding var balance: Balance?
    @Binding var balanceIndex: Int
    @Binding var amountLastUsed: Amount

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var withdrawalAmountDetails: WithdrawalAmountDetails? = nil
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
//    @State var ageMenuList: [Int] = []
//    @State var selectedAge = 0
    @State private var exchanges: [Exchange] = []
    @State private var exchange: Exchange? = nil

    private func exchangeVia(_ baseURL: String?) -> String? {
        if let baseURL {
            return String(localized: "via \(baseURL.trimURL)")
        }
        return nil
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif

        let coinData = CoinData(details: withdrawalAmountDetails)
       Group {
            if let balance {
                let scopeInfo = balance.scopeInfo
                let currency = scopeInfo.currency
//            let currencyInfo = controller.info(for: currency, controller.currencyTicker)
                let baseURL = exchange?.exchangeBaseUrl ?? scopeInfo.url        // nil for global currency

//              let agePicker = AgePicker(ageMenuList: $ageMenuList, selectedAge: $selectedAge)

//              let restrictAge: Int? = (selectedAge == 0) ? nil
//                                                         : selectedAge
//  let _ = print(selectedAge, restrictAge)
                let destination = ManualWithdrawDone(stack: stack.push(),
                                              currencyInfo: $currencyInfo,
                                                  exchange: nil,    // exchange,
                                                   balance: balance,
                                          amountToTransfer: amountToTransfer)
//                                             restrictAge: restrictAge)
                let disabled = amountToTransfer.isZero || coinData.invalid || coinData.tooMany
                let tosAccepted = (exchange?.tosStatus == .accepted) ?? false

              VStack(alignment: .trailing) {
                Text(exchangeVia(baseURL) ?? currency)
                    .multilineTextAlignment(.center)
                    .talerFont(.body)
                if tosAccepted {
                    CurrencyInputView(currencyInfo: currencyInfo,
                                            amount: $amountToTransfer,
                                    amountLastUsed: amountLastUsed,
                                         available: nil,
                                             title: minimalistic ? String(localized: "Amount:")
                                                                 : String(localized: "Amount to withdraw:"),
                                    shortcutAction: nil)
                        .padding(.top)
                    QuiteSomeCoins(currencyInfo: $currencyInfo,
//                                amountEffective: withdrawalAmountDetails?.amountEffective,
                                       currency: currency,
                                       coinData: coinData,
                                  shouldShowFee: true,           // TODO: set to false if we never charge withdrawal fees
                                  feeIsNegative: true)
//                  agePicker
                    NavigationLink(destination: destination) {
                        Text("Confirm Withdrawal")      // VIEW_WITHDRAW_ACCEPT
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                    .disabled(disabled)
                    .padding(.top)
                } else if let baseURL {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: baseURL,
                                 viewID: VIEW_WITHDRAW_TOS,                     // 31 WithdrawTOSView   TODO: YIKES might be withdraw-exchange
                                    p2p: false,
                           acceptAction: nil)
                    .padding(.top)
                }
              }.padding(.horizontal) // VStack
            } else {    // got no balance yet
                Text("No balance. There seems to be a problem with the database...")
            }
        } // Group
//        .task(id: amountToTransfer.value) { // re-run this whenever amountToTransfer changes
//            if let exchangeBaseUrl = scopeInfo?.url {
//                symLog.log("getExchangeByUrl(\(exchangeBaseUrl))")
//                if exchange == nil || exchange?.tosStatus != .accepted {
//                    exchange = try? await model.getExchangeByUrl(url: exchangeBaseUrl)
//                }
//                if !amountToTransfer.isZero {
//                    do {
//                        let details = try await model.getWithdrawalDetailsForAmountM(exchangeBaseUrl,
//                                                                              amount: amountToTransfer,
//                                                                         viewHandles: true)
//                        withdrawalAmountDetails = details
////                      agePicker.setAges(ages: withdrawalAmountDetails?.ageRestrictionOptions)
//                    } catch WalletBackendError.walletCoreError(let walletBackendResponseError) {
//                        symLog.log(walletBackendResponseError?.hint)
//                        // TODO: ignore WALLET_CORE_REQUEST_CANCELLED but handle all others
//                        // Passing non-nil to clientCancellationId will throw WALLET_CORE_REQUEST_CANCELLED
//                        // when calling getWithdrawalDetailsForAmount again before the last call returned.
//                        // Since amountToTransfer changed and we don't need the old fee anymore, we just
//                        // ignore it and do nothing.
//                    } catch {
//                        symLog.log(error.localizedDescription)
//                        withdrawalAmountDetails = nil
//                    }
//                }
//            }
//        }
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
