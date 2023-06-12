/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct WithdrawAcceptView: View {
    private let symLog = SymLogV()
    let url: URL
    @ObservedObject var model: WithdrawModel

    let navTitle = String(localized: "Accept Withdrawal")
    let detailsForAmount: ManualWithdrawalDetails
    let baseURL: String

    func acceptAction() -> () {
        Task {
            do {
                let confirmTransferUrl = try await model.sendAcceptIntWithdrawalM(baseURL, withdrawURL: url.absoluteString)
                symLog.log(confirmTransferUrl as Any)
                // TODO: Show Hints that User should Confirm on bank website
                // update balances to show pending withdrawal
                await BalancesModel.model(currency: "*").fetchBalancesM()
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }

    var body: some View {
        Group {
            let currState = model.withdrawState
            switch currState {
                case .receivedAmountDetails, .receivedTOS, .receivedTOSAck:
                    let raw = detailsForAmount.amountRaw
                    let effective = detailsForAmount.amountEffective
                    let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
                    let outColor = WalletColors().transactionColor(false)
                    let inColor = WalletColors().transactionColor(true)

                    ThreeAmountsView(topTitle: String(localized: "Chosen amount to withdraw:"),
                                     topAmount: raw, fee: fee,
                                     bottomTitle: String(localized: "Coins to be withdrawn:"),
                                     bottomAmount: effective,
                                     large: false, pending: false, incoming: true,
                                     baseURL: baseURL)
                    .safeAreaInset(edge: .bottom) {
                        Button(String(localized: "Accept"), action: acceptAction)
                            .buttonStyle(TalerButtonStyle(type: .prominent))
                            .padding(.horizontal)
                    }
                case .waitingForWithdrAck, .receivedWithdrAck:
                    // TODO: SHEET_WITHDRAW_CONFIRM
                    Text("waiting for bank confirmation")
                        .navigationTitle("Confirm with Bank")
                        .onAppear() {
                            DebugViewC.shared.setSheetID(SHEET_WITHDRAW_CONFIRM)
                        }

                default:
                    let _ = symLog.vlog(currState as Any)
                    ErrorView(errortext: "unknown state")       // TODO: Error
            }
        }
        .navigationTitle(navTitle)
        .onAppear() {
            DebugViewC.shared.setSheetID(SHEET_WITHDRAW_ACCEPT)
        }
    }
}
