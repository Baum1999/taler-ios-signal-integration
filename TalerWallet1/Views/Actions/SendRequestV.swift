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

struct SendRequestV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var balances: [Balance]
//    @Binding var currencyInfo: CurrencyInfo
//    let amountAvailable: Amount
    //    let currency: String                        // this is the currency to be used
    @Binding var amountToTransfer: Amount       // does still have the wrong currency
    @Binding var summary: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
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
        NotificationCenter.default.post(name: button == 1 ? .SendAction : .RequestAction,
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

    private var canSend: Bool {
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
        let sendTitle = String(localized: "SendButton_Short", defaultValue: "Send",
                                 comment: "Abbreviation of button `Send (currency)´")
        let requTitle = String(localized: "RequestButton_Short", defaultValue: "Request",
                                 comment: "Abbreviation of button `Request (currency)´")
        let twoRowButtons = TwoRowButtons(stack: stack.push(),
                                      sendTitle: sendTitle,
                                       sendType: .peerPushDebit,
                                       sendA11y: sendTitle,//1.tabbed(oneLine: true),
                                      recvTitle: requTitle,
                                       recvType: .peerPullCredit,
                                       recvA11y: requTitle,//1.tabbed(oneLine: true),
                                      lineLimit: 5,
                                   sendDisabled: !canSend,
                                     sendAction: { controller.frontendState = -1; selectAndUpdate(1)  },
                                     recvAction: { controller.frontendState = 1; selectAndUpdate(2) })
        Group {
            if #available(iOS 16.0, *) {
                twoRowButtons
            } else { // view for iOS 15
                twoRowButtons
            }
        }
    }
}
// MARK: -
#if  false
struct SendRequestV_Previews: PreviewProvider {
    @MainActor
  struct StateContainer: View {
    var body: some View {
        let test = Amount(currency: TESTCURRENCY, cent: 123)
        let demo = Amount(currency: DEMOCURRENCY, cent: 123456)

        List {
            Section {
                SendRequestV(stack: CallStack("Preview"), currencyName: DEMOCURRENCY, amount: demo,
                          sendAction: {}, recvAction: {}, rowAction: {}, balanceDest: nil)
            }
            SendRequestV(stack: CallStack("Preview"), currencyName: TESTCURRENCY, amount: test,
                      sendAction: {}, recvAction: {}, rowAction: {}, balanceDest: nil)
        }
    }
  }

    static var previews: some View {
        StateContainer()
//            .environment(\.sizeCategory, .extraExtraLarge)    Canvas Device Settings
    }
}
#endif
