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

// Called either when scanning a QR code or tapping the provided link, both from the bank's website.
// We show the user the withdrawal details in a sheet - but first the ToS must be accepted.
// After the user confirmed the withdrawal, we show a button to return to the bank website to confirm there, too
struct WithdrawURIView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Withdrawal")

    // the URL from the bank website
    let url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var withdrawalAmountDetails: WithdrawalAmountDetails? = nil
    @State private var exchange: Exchange? = nil

    var body: some View {
        VStack {
            if let withdrawalAmountDetails, let exchange {
                let tosAccepted = exchange.tosStatus == .accepted
                if !tosAccepted {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: exchange.exchangeBaseUrl,
                                 viewID: SHEET_WITHDRAW_TOS,
                                    p2p: false)
                }
                List {
                    let raw = withdrawalAmountDetails.amountRaw
                    let effective = withdrawalAmountDetails.amountEffective
                    let currency = raw.currencyStr
                    let currencyInfo = controller.info(for: currency, controller.currencyTicker)
                    let fee = try! Amount.diff(raw, effective)
                    let outColor = WalletColors().transactionColor(false)
                    let inColor = WalletColors().transactionColor(true)

                    ThreeAmountsV(stack: stack.push(),
                                  topTitle: String(localized: "Chosen amount to withdraw:"),
                                 topAbbrev: String(localized: "Chosen:", comment: "mini"),
                                 topAmount: raw, fee: fee,
                               bottomTitle: String(localized: "Amount to be withdrawn:"),
                              bottomAbbrev: String(localized: "Effective:", comment: "mini"),
                              bottomAmount: effective,
                                     large: false, pending: false, incoming: true,
                                   baseURL: exchange.exchangeBaseUrl,
                                    status: nil,        // common.txState.major.localizedState
                                   summary: nil,
                                  merchant: nil)
                    let someCoins = SomeCoins(details: withdrawalAmountDetails)
                    QuiteSomeCoins(someCoins: someCoins,
                               shouldShowFee: true,       // TODO: set to false if we never charge withdrawal fees
                                    currency: currency,
                                currencyInfo: currencyInfo,
                             amountEffective: effective)
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                if tosAccepted {
                    NavigationLink(destination: LazyView {
                        WithdrawAcceptDone(stack: stack.push(),
                                 exchangeBaseUrl: exchange.exchangeBaseUrl,
                                             url: url)
                    }) {
                        Text("Confirm Withdrawal")      // SHEET_WITHDRAW_ACCEPT
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
                }
            } else {        // no details or no exchange
#if DEBUG
                let message = url.host
#else
                let message: String? = nil
#endif
                LoadingView(scopeInfo: nil, message: message)
            }
        }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_WITHDRAWAL)
        }
        .task {
            do { // TODO: cancelled
                symLog.log(".task")
                let withdrawUriInfo = try await model.getWithdrawalDetailsForUriM(url.absoluteString)
                let amount = withdrawUriInfo.amount
                let baseUrl = withdrawUriInfo.defaultExchangeBaseUrl
                           ?? withdrawUriInfo.possibleExchanges.first?.exchangeBaseUrl
                if let baseUrl {
                    exchange = try await model.getExchangeByUrl(url: baseUrl)
                    let details = try await model.getWithdrawalDetailsForAmountM(baseUrl, amount: amount)
                    withdrawalAmountDetails = details
//                    agePicker.setAges(ages: details?.ageRestrictionOptions)
                } else {    // TODO: error
                    symLog.log("no exchangeBaseUrl or no exchange")
                    withdrawalAmountDetails = nil
                }
            } catch {
                symLog.log(error.localizedDescription)
                model.showError(.error(error))
                controller.playSound(0)
                withdrawalAmountDetails = nil
            }
        }
    }
}
