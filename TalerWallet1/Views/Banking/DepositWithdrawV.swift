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

struct DepositWithdrawV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scopeInfo: ScopeInfo
    let amountAvailable: Amount?
    let currency: String                        // this is the currency to be used
    @Binding var amountToTransfer: Amount       // does still have the wrong currency

    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var buttonSelected: Int? = nil
    @State private var myExchange: Exchange? = nil

    func selectAndUpdate(_ button: Int) {
        amountToTransfer.setCurrency(currency)
        buttonSelected = button      // will trigger NavigationLink
        // after user tapped a button, while navigation animation runs, contact Exchange to update Fees
        if let url = scopeInfo.url {
            Task { // runs on MainActor
                do {
//                    try await model.updateExchange(scopeInfo: scopeInfo)
                    try await model.updateExchange(exchangeBaseUrl: url)
                } catch {    // TODO: error handling - couldn't updateExchange
                    symLog.log("error: \(error)")
                }
            }
        }
    }

    var body: some View {
        let depositTitle0 = String(localized: "DepositButton_Short", defaultValue: "Deposit",
                                     comment: "Abbreviation of button `Deposit (currency)´")
        let depositTitle1 = String(localized: "Deposit\t\(currency)",
                                     comment: "Button `Deposit (currency)´, must have ONE \\t and ONE %@")

        let withdrawTitle0 = String(localized: "WithdrawButton_Short", defaultValue: "Withdraw",
                                      comment: "Abbreviation of button `Withdraw (currency)´")
        let withdrawTitle1 = String(localized: "Withdraw\t\(currency)",
                                      comment: "Button `Withdraw (currency)´, must have ONE \\t and ONE %@")
        let deposit = LazyView {
            DepositIbanV(stack: stack.push(),
                      feeLabel: nil,
                  feeIsNotZero: nil,
               amountAvailable: amountAvailable,
//                   depositIBAN: $depositIBAN,
//                 accountHolder: $accountHolder,
              amountToTransfer: $amountToTransfer)
        }
        let manualWithdraw = LazyView {
            ManualWithdraw(stack: stack.push(),
                         isSheet: false,
                       scopeInfo: scopeInfo,
                        exchange: $myExchange,
                amountToTransfer: $amountToTransfer)
        }
        let disableDeposit = amountAvailable?.isZero ?? false
        let twoRowButtons = TwoRowButtons(stack: stack.push(),
                                      sendTitle: minimalistic ? depositTitle0 : depositTitle1,
                                       sendType: .deposit,
                                       sendA11y: depositTitle1.tabbed(oneLine: true),
                                      recvTitle: minimalistic ? withdrawTitle0 : withdrawTitle1,
                                       recvType: .withdrawal,
                                       recvA11y: withdrawTitle1.tabbed(oneLine: true),
                                 fitsSideBySide: false,
                                      lineLimit: 5,
                                   sendDisabled: disableDeposit,
                                     sendAction: { selectAndUpdate(1) },
                                     recvAction: { selectAndUpdate(2) })
        Group {
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: HSPACING) {
                        twoRowButtons.makeCopy(fitsSideBySide: true)
                    }
                    VStack { twoRowButtons }
                }
            } else { // view for iOS 15
                VStack { twoRowButtons }
            }
        }
        .background( Group {
            NavigationLink(destination: deposit, tag: 1, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
            NavigationLink(destination: manualWithdraw, tag: 2, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
        })
    }
}
