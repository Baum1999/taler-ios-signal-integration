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

struct WithdrawAcceptView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Withdrawal")

    // the URL from the bank website
    let url: URL
    let scope: ScopeInfo
    @Binding var amountToTransfer: Amount
    @Binding var wireFee: Amount?
    @Binding var exchange: Exchange?            // user can select one from possibleExchanges

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
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(scope.url ?? amountToTransfer.readableDescription)       // just to get the #
#endif
        ZStack {  // there is only _one_ Z item ever - use ZStack to ensure .task is run only _once_ when exchange is switched
          if let exchange2 = exchange {     // there should always be an exchange...
            VStack {
                let tosAccepted = exchange2.tosStatus == .accepted
                if !tosAccepted {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: exchange2.exchangeBaseUrl,
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
                                           noFees: exchange2.noFees,
                                              fee: fee,
                                    feeIsNegative: true,
                                      bottomTitle: String(localized: "Amount to obtain:"),
                                     bottomAbbrev: String(localized: "Obtain:", comment: "Amount to obtain:"),
                                     bottomAmount: effective,
                                            large: false,
                                    pendingDialog: false,
                                           isDone: false,
                                         incoming: true,
                                          baseURL: exchange2.exchangeBaseUrl,
                                       txStateLcl: nil,        // common.txState.major.localizedState
                                          summary: nil,
                                         products: nil)
                        if let wireFee {
                            if !wireFee.isZero {
                                let currencyInfo = controller.info(for: scope, controller.currencyTicker)
                                let feeStr = wireFee.formatted(currencyInfo, isNegative: false)
                                let feeTitle = String(localized: "FEE_WITHDRAW_BANK_WIRE",
                                                   defaultValue: "Your bank's wire fee: \(feeStr.0)")
                                let feeA11y = String(localized: "FEE_WITHDRAW_BANK_WIRE_A11Y",
                                                  defaultValue: "Your bank's wire fee: \(feeStr.1)", comment: "a11y")
                                Text(feeTitle)
                                    .accessibilityLabel(Text(feeA11y))
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
                                                   exchangeBaseUrl: exchange2.exchangeBaseUrl,
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
          } else {        // no exchange - should not happen
#if DEBUG
            let message = url.host
#else
            let message: String? = nil
#endif
            let _ = symLog.log("Loading")
            LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
          }
        }
        .task(id: exchange?.id) {     // re-run this whenever the user switches the exchange
            await viewDidLoad()
        }
    }
}
