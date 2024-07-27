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
    @Binding var currencyInfo: CurrencyInfo
    let amountAvailable: Amount?
//    let currency: String                        // this is the currency to be used
    @Binding var amountToTransfer: Amount       // does still have the wrong currency

    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var buttonSelected: Int? = nil
    @State private var myExchange: Exchange? = nil

    func selectAndUpdate(_ button: Int) {
        let scope = currencyInfo.scope
        let currency = scope.currency
        amountToTransfer.setCurrency(currency)
        buttonSelected = button      // will trigger NavigationLink
        // after user tapped a button, while navigation animation runs, contact Exchange to update Fees
        if let url = scope.url {
            Task { // runs on MainActor
                do {
    // TODO:        try await model.updateExchange(scopeInfo: scope)
                    try await model.updateExchange(exchangeBaseUrl: url)
                } catch {    // TODO: error handling - couldn't updateExchange
                    symLog.log("error: \(error)")
                }
            }
        }
    }

    var body: some View {
        let scope = currencyInfo.scope
        let currencyName = currencyInfo.specs.name
        let depositTitle0 = String(localized: "DepositButton_Short", defaultValue: "Deposit",
                                     comment: "Abbreviation of button `Deposit (currency)´")
        let depositTitle1 = String(localized: "Deposit\t\(currencyName)",
                                     comment: "Button `Deposit (currency)´, must have ONE \\t and ONE %@")
        let depositTitle = minimalistic ? depositTitle0 : depositTitle1
        let withdrawTitle0 = String(localized: "WithdrawButton_Short", defaultValue: "Withdraw",
                                      comment: "Abbreviation of button `Withdraw (currency)´")
        let withdrawTitle1 = String(localized: "Withdraw\t\(currencyName)",
                                      comment: "Button `Withdraw (currency)´, must have ONE \\t and ONE %@")
        let withdrawTitle = minimalistic ? withdrawTitle0 : withdrawTitle1
        let depositDest = LazyView {
            DepositIbanV(stack: stack.push(),
                  currencyInfo: $currencyInfo,
                      feeLabel: nil,
                  feeIsNotZero: nil,
               amountAvailable: amountAvailable,
//                   depositIBAN: $depositIBAN,
//                 accountHolder: $accountHolder,
              amountToTransfer: $amountToTransfer)
        }
        let manualWithdrawDest = LazyView {
            ManualWithdraw(stack: stack.push(),
                    currencyInfo: $currencyInfo,
                         isSheet: false,
                       scopeInfo: scope,
                        exchange: $myExchange,
                amountToTransfer: $amountToTransfer)
        }
        let disableDeposit = amountAvailable?.isZero ?? false
        let twoRowButtons = TwoRowButtons(stack: stack.push(),
                                      sendTitle: depositTitle,
                                       sendType: .deposit,
                                       sendA11y: depositTitle1.tabbed(oneLine: true),
                                      recvTitle: withdrawTitle,
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
            NavigationLink(destination: depositDest, tag: 1, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
            NavigationLink(destination: manualWithdrawDest, tag: 2, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
        })
    }
}
