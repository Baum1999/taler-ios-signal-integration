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

struct WithdrawAcceptView: View {
    private let symLog = SymLogV()
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
    let navTitle = String(localized: "Withdrawal")

    // the URL from the bank website
    let url: URL
    @Binding var amountToTransfer: Amount
    @Binding var exchange: Exchange?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var withdrawalAmountDetails: WithdrawalAmountDetails? = nil

    func reloadExchange() async -> Void {        // TODO: throws?
        if let exchange {
            if let someExchange = try? await model.getExchangeByUrl(url: exchange.exchangeBaseUrl) {
                self.exchange = someExchange
            }
        }
    }

    var body: some View {
        if let exchange, let withdrawalAmountDetails {
            VStack {
                let tosAccepted = exchange.tosStatus == .accepted
                if !tosAccepted {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: exchange.exchangeBaseUrl,
                                 viewID: SHEET_WITHDRAW_TOS,
                                    p2p: false,
                           acceptAction: reloadExchange)
                }
                List {
                    let raw = withdrawalAmountDetails.amountRaw
                    let effective = withdrawalAmountDetails.amountEffective
                    let currency = raw.currencyStr
                    let currencyInfo = controller.info(for: currency, controller.currencyTicker)
                    let fee = try! Amount.diff(raw, effective)
                    let outColor = WalletColors().transactionColor(false)
                    let inColor = WalletColors().transactionColor(true)

                    ThreeAmountsSection(stack: stack.push(),
                                 currencyInfo: $currencyInfo,
                                     topTitle: String(localized: "Chosen amount to withdraw:"),
                                    topAbbrev: String(localized: "Withdraw:", comment: "Chosen amount to withdraw:"),
                                    topAmount: raw, fee: fee,
                                  bottomTitle: String(localized: "Amount to obtain:"),
                                 bottomAbbrev: String(localized: "Obtain:", comment: "Amount to obtain:"),
                                 bottomAmount: effective,
                                        large: false, pending: false, incoming: true,
                                      baseURL: exchange.exchangeBaseUrl,
                                       noFees: exchange.noFees,
                                   txStateLcl: nil,        // common.txState.major.localizedState
                                      summary: nil,
                                     merchant: nil)
                    let coinData = CoinData(details: withdrawalAmountDetails)
                    QuiteSomeCoins(currencyInfo: $currencyInfo,
                                       currency: currency,
                                       coinData: coinData,
                                  shouldShowFee: true,       // TODO: set to false if we never charge withdrawal fees
                                amountEffective: effective)
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                if tosAccepted {
                    NavigationLink(destination: LazyView {
                        WithdrawAcceptDone(stack: stack.push(),
                                    currencyInfo: $currencyInfo,
                                 exchangeBaseUrl: exchange.exchangeBaseUrl,
                                             url: url,
                                amountToTransfer: amountToTransfer)
                    }) {
                        Text("Confirm Withdrawal")      // SHEET_WITHDRAW_ACCEPT
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
                }
            }
            .onAppear() {
                symLog.log("onAppear")
                DebugViewC.shared.setSheetID(SHEET_WITHDRAW_ACCEPT)             // 132 WithdrawAcceptView
            }
        } else {        // no details or no exchange
#if DEBUG
            let message = url.host
#else
            let message: String? = nil
#endif
            LoadingView(scopeInfo: nil, message: message)
                .task(id: exchange?.id) {
                    symLog.log(".task \(exchange?.id ?? "nil")")
                    if let exchange {
                        if let details = try? await model.getWithdrawalDetailsForAmountM(exchange.exchangeBaseUrl,
                                                                                  amount: amountToTransfer) {
                            withdrawalAmountDetails = details
                        }
//                    agePicker.setAges(ages: details?.ageRestrictionOptions)
                    } else {    // TODO: error
                        symLog.log("no exchangeBaseUrl or no exchange")
                        withdrawalAmountDetails = nil
                    }
                }
        }
    }
}
