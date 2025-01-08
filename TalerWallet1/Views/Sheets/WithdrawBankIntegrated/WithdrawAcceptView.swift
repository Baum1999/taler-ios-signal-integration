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
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Withdrawal")

    // the URL from the bank website
    let url: URL
    let scope: ScopeInfo
    @Binding var amountToTransfer: Amount
    @Binding var wireFee: Amount?
    @Binding var exchange: Exchange?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var withdrawalDetails: WithdrawalDetailsForAmount? = nil

    @MainActor
    func reloadExchange() async -> Void {        // TODO: throws?
        if let exchange {
            if let someExchange = try? await model.getExchangeByUrl(url: exchange.exchangeBaseUrl) {
                self.exchange = someExchange
            }
        }
    }

    @MainActor
    private func viewDidLoad() async {
        symLog.log(".task \(exchange?.id ?? "nil")")
        if !amountToTransfer.isZero, let exchange {
            if let details = try? await model.getWithdrawalDetailsForAmount(amountToTransfer,
                                                                   baseUrl: exchange.exchangeBaseUrl,
                                                                     scope: nil) { // TODO: scope
                withdrawalDetails = details
            }
//          agePicker.setAges(ages: details?.ageRestrictionOptions)
        } else {    // TODO: error
            symLog.log("no exchangeBaseUrl or no exchange")
            withdrawalDetails = nil
        }
    }

    var body: some View {
        if let exchange {
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
                    if let withdrawalDetails {
                        let raw = withdrawalDetails.amountRaw
                        let effective = withdrawalDetails.amountEffective
                        let currency = raw.currencyStr
                        let fee = try! Amount.diff(raw, effective)
                        let outColor = WalletColors().transactionColor(false)
                        let inColor = WalletColors().transactionColor(true)

                        ThreeAmountsSection(stack: stack.push(),
                                            scope: scope,
                                         topTitle: String(localized: "Chosen amount to withdraw:"),
                                        topAbbrev: String(localized: "Withdraw:", comment: "Chosen amount to withdraw:"),
                                        topAmount: raw,
                                           noFees: exchange.noFees,
                                              fee: fee,
                                    feeIsNegative: true,
                                      bottomTitle: String(localized: "Amount to obtain:"),
                                     bottomAbbrev: String(localized: "Obtain:", comment: "Amount to obtain:"),
                                     bottomAmount: effective,
                                            large: false,
                                          pending: false,
                                         incoming: true,
                                          baseURL: exchange.exchangeBaseUrl,
                                       txStateLcl: nil,        // common.txState.major.localizedState
                                          summary: nil,
                                         merchant: nil,
                                         products: nil)
                        if let wireFee {
                            if !wireFee.isZero {
                                let currencyInfo = controller.info(for: scope, controller.currencyTicker)
                                let feeStr = wireFee.formatted(currencyInfo, isNegative: false)
                                Text("Your bank's wire fee: \(feeStr)")
                            }
                        }
                    } else {
                        Section {
                            Text("The amount will be determined by the Cash Acceptor.")
                        }
                    }
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                .safeAreaInset(edge: .bottom) {
                    if tosAccepted {
                        let destination = WithdrawAcceptDone(stack: stack.push(),
//                                                             scope: scope,
                                                   exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                               url: url,
                                                  amountToTransfer: amountToTransfer.isZero ? nil : amountToTransfer)
                        NavigationLink(destination: destination) {
                            Text("Confirm Withdrawal")      // SHEET_WITHDRAW_ACCEPT
                        }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                    }
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
                .task(id: exchange?.id) { await viewDidLoad() }
        }
    }
}
