/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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

    // the exchange used for this withdrawal.
    @State private var exchangeBaseUrl: String? = nil
    @State private var withdrawalAmountDetails: WithdrawalAmountDetails?

    var body: some View {
        let badURL = "Error in URL: \(url)"
        VStack {
            if let withdrawalAmountDetails, let exchangeBaseUrl {
                List {
                    let raw = withdrawalAmountDetails.amountRaw
                    let effective = withdrawalAmountDetails.amountEffective
                    let currency = raw.currencyStr
                    let currencyInfo = controller.info(for: currency, controller.currencyTicker)
                    let fee = try! Amount.diff(raw, effective)
                    let outColor = WalletColors().transactionColor(false)
                    let inColor = WalletColors().transactionColor(true)

                    ThreeAmountsV(topTitle: String(localized: "Chosen amount to withdraw:"),
                                 topAbbrev: String(localized: "Chosen:"),
                                 topAmount: raw, fee: fee,
                               bottomTitle: String(localized: "Amount to be withdrawn:"),
                              bottomAbbrev: String(localized: "Effective:"),
                              bottomAmount: effective,
                                     large: false, pending: false, incoming: true,
                                   baseURL: exchangeBaseUrl)
                    let someCoins = SomeCoins(details: withdrawalAmountDetails)
                    QuiteSomeCoins(someCoins: someCoins,
                               shouldShowFee: true,       // TODO: set to false if we never charge withdrawal fees
                                    currency: currency,
                                currencyInfo: currencyInfo,
                             amountEffective: effective)
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                let tosAccepted = withdrawalAmountDetails.tosAccepted
                if tosAccepted {
                    NavigationLink(destination: LazyView {
                        WithdrawAcceptDone(stack: stack.push(),
                                 exchangeBaseUrl: exchangeBaseUrl,
                                             url: url)
                    }) {
                        Text("Confirm Withdrawal")      // SHEET_WITHDRAW_ACCEPT
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
                } else {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: exchangeBaseUrl,
                                 viewID: SHEET_WITHDRAW_TOS,
                                    p2p: false)
                }
            } else {
                // Yikes no details or no baseURL
                WithdrawProgressView(message: url.host ?? badURL)
                    .navigationTitle("Contacting Exchange")
            }
        }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_WITHDRAWAL)
        }
        .task {
            do { // TODO: cancelled
                symLog.log(".task")
                let withdrawUriInfo = try await model.loadWithdrawalDetailsForUriM(url.absoluteString)
                exchangeBaseUrl = withdrawUriInfo.defaultExchangeBaseUrl ??
                                  withdrawUriInfo.possibleExchanges.first?.exchangeBaseUrl
                if let exchangeBaseUrl {
                    let amount = withdrawUriInfo.amount
                    let details = try await model.loadWithdrawalDetailsForAmountM(exchangeBaseUrl, amount: amount)
                    withdrawalAmountDetails = details
//                  agePicker.setAges(ages: details?.ageRestrictionOptions)
                } else {    // TODO: error
                    symLog.log("no exchangeBaseUrl")
                    withdrawalAmountDetails = nil
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                withdrawalAmountDetails = nil
            }
        }
    }
}
