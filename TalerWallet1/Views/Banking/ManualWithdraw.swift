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

// Will be called by either the user tapping "Withdraw Coins" in the exchanges list
// or from WithdrawExchangeV after a withdraw-exchange QR was scanned
struct ManualWithdraw: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let isSheet: Bool
//    let exchangeBaseUrl: String
    let scopeInfo: ScopeInfo?
    @Binding var exchange: Exchange?
    @Binding var amountToTransfer: Amount

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var withdrawalAmountDetails: WithdrawalAmountDetails? = nil
//    @State var ageMenuList: [Int] = []
//    @State var selectedAge = 0

    fileprivate let sheetID = SHEET_WITHDRAW_EXCHANGE                           // 135 WithdrawExchangeV
    fileprivate let viewID = VIEW_WITHDRAWAL                                    // 30 WithdrawAmount
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let baseURL = exchange?.exchangeBaseUrl
                   ?? scopeInfo?.url
                   ?? String(localized: "Unknown Payment Service")

      Group {
        if let exchange {
            let currency = exchange.scopeInfo.currency
            let currencyInfo = controller.info(for: currency, controller.currencyTicker)
            let currencySymbol = currencyInfo.specs.altUnitNames?[0] ?? currency
            let navTitle = String(localized: "NavTitle_Withdraw (currency)",
                               defaultValue: "Withdraw \(currencySymbol)",
                                    comment: "NavTitle: Withdraw 'currencySymbol'")
            let navA11y = String(localized: "NavTitle_Withdraw (currency) A11y",
                                 defaultValue: "Withdraw \(currency)",
                                 comment: "NavTitle: Withdraw 'currency'")
//          let agePicker = AgePicker(ageMenuList: $ageMenuList, selectedAge: $selectedAge)

            let coinData = CoinData(details: withdrawalAmountDetails)
//          let restrictAge: Int? = (selectedAge == 0) ? nil
//                                                     : selectedAge
//  let _ = print(selectedAge, restrictAge)
            let destination = LazyView {
                ManualWithdrawDone(stack: stack.push(),
                                exchange: exchange,
                        amountToTransfer: amountToTransfer)
//                           restrictAge: restrictAge)
            }
            let disabled = amountToTransfer.isZero || coinData.invalid || coinData.tooMany
            let tosAccepted = exchange.tosStatus == .accepted
            ScrollView { VStack(alignment: .trailing) {
                Text("via \(exchange.exchangeBaseUrl.trimURL())")
                    .multilineTextAlignment(.center)
                    .talerFont(.body)
                if tosAccepted {
                    CurrencyInputView(amount: $amountToTransfer,
                                   available: nil,
                                       title: minimalistic ? String(localized: "Amount:")
                                                           : String(localized: "Amount to withdraw:"),
                              shortcutAction: nil)
                        .padding(.top)
                    QuiteSomeCoins(currencyInfo: currencyInfo,
                                       currency: currency,
                                       coinData: coinData,
                                  shouldShowFee: true,           // TODO: set to false if we never charge withdrawal fees
                                amountEffective: withdrawalAmountDetails?.amountEffective)
//                  agePicker
                    NavigationLink(destination: destination) {
                        Text("Confirm Withdrawal")      // VIEW_WITHDRAW_ACCEPT
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                    .disabled(disabled)
                    .padding(.top)
                } else {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: exchange.exchangeBaseUrl,
                                 viewID: VIEW_WITHDRAW_TOS,                     // 31 WithdrawTOSView   TODO: YIKES might be withdraw-exchange
                                    p2p: false,
                           acceptAction: nil)
                    .padding(.top)
                }
            }.padding(.horizontal) } // ScrollVStack
            .frame(maxWidth: .infinity, alignment: .leading)
//            .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
            .navigationTitle(navTitle)
            .onAppear {
                if isSheet {
                    DebugViewC.shared.setSheetID(sheetID)
                } else {
                    DebugViewC.shared.setViewID(viewID, stack: stack.push())
                }
                symLog.log("❗️ \(navTitle) onAppear")
            }
            .onDisappear {
                symLog.log("❗️ \(navTitle) onDisappear")
            }
        } else {
            let contacting = String(localized: "Contacting...")
            LoadingView(scopeInfo: scopeInfo, message: contacting)
        }
      }
        .task(id: amountToTransfer.value) { // re-run this whenever amountToTransfer changes
            if let exchangeBaseUrl = scopeInfo?.url {
                symLog.log("getExchangeByUrl(\(exchangeBaseUrl))")
                if exchange == nil || exchange?.tosStatus != .accepted {
                    exchange = try? await model.getExchangeByUrl(url: exchangeBaseUrl)
                }
                if !amountToTransfer.isZero {
                    do {
                        let details = try await model.getWithdrawalDetailsForAmountM(exchangeBaseUrl,
                                                                              amount: amountToTransfer,
                                                                      cancellationId: "cancel",
                                                                         viewHandles: true)
                        withdrawalAmountDetails = details
//                      agePicker.setAges(ages: withdrawalAmountDetails?.ageRestrictionOptions)
                    } catch WalletBackendError.walletCoreError(let walletBackendResponseError) {
                        symLog.log(walletBackendResponseError?.hint)
                        // TODO: ignore WALLET_CORE_REQUEST_CANCELLED but handle all others
                        // Passing non-nil to clientCancellationId will throw WALLET_CORE_REQUEST_CANCELLED
                        // when calling getWithdrawalDetailsForAmount again before the last call returned.
                        // Since amountToTransfer changed and we don't need the old fee anymore, we just
                        // ignore it and do nothing.
                    } catch {
                        symLog.log(error.localizedDescription)
                        withdrawalAmountDetails = nil
                    }
                }
            }
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
