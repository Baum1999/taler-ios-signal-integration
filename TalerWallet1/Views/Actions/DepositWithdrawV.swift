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
    @Binding var balances: [Balance]
//    @Binding var currencyInfo: CurrencyInfo
//    let amountAvailable: Amount?
//    let currency: String                        // this is the currency to be used
    @Binding var amountToTransfer: Amount       // does still have the wrong currency

    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var currencyName: String = UNKNOWN
    @State private var currencySymbol: String = UNKNOWN
    @State private var amountAvailable = Amount.zero(currency: EMPTYSTRING)     // Update currency when used

    func selectAndUpdate(_ button: Int) {
        let scope = currencyInfo.scope
        let currency = scope.currency
        amountToTransfer.setCurrency(currency)
        dismissTop(stack.push())
        NotificationCenter.default.post(name: button == 3 ? .DepositAction : .WithdrawAction,
                                      object: nil)                              // will trigger NavigationLink
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

    private var canDeposit: Bool {
        for balance in balances {
            if !balance.available.isZero {
                return true
            }
        }
        return false
    }

    var body: some View {
        let scope = currencyInfo.scope
        let currencyName = currencyInfo.specs.name
        let depositTitle = String(localized: "DepositButton_Short", defaultValue: "Deposit",
                                    comment: "Abbreviation of button `Deposit (currency)´")
        let withdrawTitle = String(localized: "WithdrawButton_Short", defaultValue: "Withdraw",
                                     comment: "Abbreviation of button `Withdraw (currency)´")
        let twoRowButtons = TwoRowButtons(stack: stack.push(),
                                      sendTitle: depositTitle,
                                       sendType: .deposit,
                                       sendA11y: depositTitle,//1.tabbed(oneLine: true),
                                      recvTitle: withdrawTitle,
                                       recvType: .withdrawal,
                                       recvA11y: withdrawTitle,//1.tabbed(oneLine: true),
                                 fitsSideBySide: false,
                                      lineLimit: 5,
                                   sendDisabled: !canDeposit,
                                     sendAction: { selectAndUpdate(3) },
                                     recvAction: { selectAndUpdate(4) })
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
    }
}
