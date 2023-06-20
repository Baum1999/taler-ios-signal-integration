/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct WithdrawAcceptView: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Accept Withdrawal")

    let exchangeBaseUrl: String
    let model: WithdrawModel?
    let amount: Amount?
    let url: URL

    @State private var buttonSelected: Int? = nil
    @State private var confirmTransferUrl: String? = nil
    @State private var transactionId: String? = nil
    @State var manualWithdrawalDetails: ManualWithdrawalDetails?

    func acceptAction() -> () {
        Task {
            do {
                if let model {
                    if let acceptWithdrawalResponse = try await model.sendAcceptIntWithdrawalM(exchangeBaseUrl, withdrawURL: url.absoluteString) {
                        confirmTransferUrl = acceptWithdrawalResponse.confirmTransferUrl
                        transactionId = acceptWithdrawalResponse.transactionId
                        symLog.log(confirmTransferUrl ?? "❗️Yikes: No confirmTransferUrl")
                        buttonSelected = 1      // trigger NavigationLink
                    } else {
                        // TODO: error sendAcceptIntWithdrawal failed
                    }
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }

    var body: some View {
        VStack {
            if let manualWithdrawalDetails {
                List {

                    HStack(spacing: 0) {
                        NavigationLink(destination: LazyView {
                            WithdrawAcceptDone(model: model, confirmTransferUrl: confirmTransferUrl, transactionId: transactionId)
                        }, tag: 1, selection: $buttonSelected
                        ) { EmptyView() }.frame(width: 0).opacity(0).hidden()

                        ThreeAmountsView(topTitle: String(localized: "Chosen amount to withdraw:"),
                                         topAmount: raw, fee: fee,
                                         bottomTitle: String(localized: "Coins to be withdrawn:"),
                                         bottomAmount: effective,
                                         large: false, pending: false, incoming: true,
                                         baseURL: exchangeBaseUrl)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button("Confirm Withdrawal", action: acceptAction)
                        .lineLimit(2)
                        .disabled(false)
                        .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, aligned: .center))
                        .padding()
                }
                .navigationTitle(navTitle)
            } else {
                WithdrawProgressView(message: exchangeBaseUrl.trimURL())
                    .navigationTitle("Found Exchange")
            }
        }
//        .overlay {
//            VStack {
//                ErrorView(errortext: "unknown state")       // TODO: Error
//            }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
//                .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
//        }
        .onAppear() {
            DebugViewC.shared.setSheetID(SHEET_WITHDRAW_ACCEPT)
        }
        .task { if let amount, let model {
            do { // TODO: cancelled
                symLog.log(".task")
                if exchangeBaseUrl.hasPrefix(HTTPS) {
                    symLog.log("amount: \(amount), baseURL: \(String(describing: exchangeBaseUrl))")
                    // TODO: let user choose exchange from list
                    manualWithdrawalDetails = try await model.loadWithdrawalDetailsForAmountM(exchangeBaseUrl, amount: amount)
                    symLog.log("raw: \(manualWithdrawalDetails!.amountRaw), effective: \(manualWithdrawalDetails!.amountEffective)")
                } else {
                    // TODO: error no exchange!
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        } else {
            // TODO: error no amount!
        } }
    }
}
// MARK: -
struct WithdrawAcceptView_Previews: PreviewProvider {
    static var previews: some View {
        let amount = try! Amount(fromString: LONGCURRENCY + ":2.4")
        WithdrawAcceptView(exchangeBaseUrl: DEMOEXCHANGE,
                                     model: nil,
                                    amount: amount,
                                       url: URL(string: DEMOSHOP)!)
    }
}
