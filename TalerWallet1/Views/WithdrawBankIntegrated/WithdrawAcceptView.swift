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
    var model: WithdrawModel?

    let navTitle = String(localized: "Accept Withdrawal")
    let detailsForAmount: ManualWithdrawalDetails
    let baseURL: String

    @State private var buttonSelected: Int? = nil
    @State private var confirmTransferUrl: String? = nil

    func acceptAction() -> () {
        Task {
            do {
                if let model {
                    if let transferUrl = try await model.sendAcceptIntWithdrawalM(baseURL, withdrawURL: url.absoluteString) {
                        symLog.log(transferUrl)
                        confirmTransferUrl = transferUrl
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
        List {
            let raw = detailsForAmount.amountRaw
            let effective = detailsForAmount.amountEffective
            let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
            let outColor = WalletColors().transactionColor(false)
            let inColor = WalletColors().transactionColor(true)

            HStack(spacing: 0) {
                NavigationLink(destination: LazyView {
                    WithdrawAcceptDone(confirmTransferUrl: confirmTransferUrl)
                }, tag: 1, selection: $buttonSelected
                ) { EmptyView() }.frame(width: 0).opacity(0).hidden()
                
                ThreeAmountsView(topTitle: String(localized: "Chosen amount to withdraw:"),
                                 topAmount: raw, fee: fee,
                                 bottomTitle: String(localized: "Coins to be withdrawn:"),
                                 bottomAmount: effective,
                                 large: false, pending: false, incoming: true,
                                 baseURL: baseURL)
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
//        .overlay {
//            VStack {
//                ErrorView(errortext: "unknown state")       // TODO: Error
//            }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
//                .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
//        }
        .onAppear() {
            DebugViewC.shared.setSheetID(SHEET_WITHDRAW_ACCEPT)
        }
    }
}
// MARK: -
struct WithdrawAcceptView_Previews: PreviewProvider {
    static var previews: some View {
        let details = ManualWithdrawalDetails(amountRaw:  try! Amount(fromString: LONGCURRENCY + ":2.4"),
                                              amountEffective:  try! Amount(fromString: LONGCURRENCY + ":2.2"),
                                              paytoUris: [],
                                              tosAccepted: true)
        WithdrawAcceptView(url: URL(string: DEMOSHOP)!,
                           model: nil,
                           detailsForAmount: details,
                           baseURL: DEMOEXCHANGE)
    }
}
