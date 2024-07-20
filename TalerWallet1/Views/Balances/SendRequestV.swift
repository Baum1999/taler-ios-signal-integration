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
    let currencyInfo: CurrencyInfo
    let amountAvailable: Amount
    //    let currency: String                        // this is the currency to be used
    @Binding var amountToTransfer: Amount       // does still have the wrong currency
    @Binding var summary: String
    let cameraAction: () -> Void

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var buttonSelected: Int? = nil

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

    private static func className() -> String {"\(self)"}

    var body: some View {
        let scope = currencyInfo.scope
        let currencyName = currencyInfo.specs.name
        let sendTitle0 = String(localized: "SendButton_Short", defaultValue: "Send",
                                  comment: "Abbreviation of button `Send (currency)´")
        let sendTitle1 = String(localized: "SendButton_Full", defaultValue: "Send\t\(currencyName)",
                                  comment: "`Send (currency)´ in Balances - must have ONE \\t and ONE %@")
        let sendTitle = minimalistic ? sendTitle0 : sendTitle1

        let requTitle0 = String(localized: "RequestButton_Short", defaultValue: "Request",
                                  comment: "Abbreviation of button `Request (currency)´")
        let requTitle1 = String(localized: "RequestButton_Full", defaultValue: "Request\t\(currencyName)",
                                  comment: "`Request (currency)´ in Balances - must have ONE \\t and ONE %@")
        let requTitle = minimalistic ? requTitle0 : requTitle1
        let sendDest = LazyView {
            SendAmount(stack: stack.push("\(Self.className())()"),
                currencyInfo: currencyInfo,
             amountAvailable: amountAvailable,
            amountToTransfer: $amountToTransfer,        // with correct currency
                     summary: $summary,
                   scopeInfo: scope,
                cameraAction: cameraAction)
        }
        let requestDest = LazyView {
            RequestPayment(stack: stack.push("\(Self.className())()"),
                amountToTransfer: $amountToTransfer,    // with correct currency
                        summary: $summary,
                      scopeInfo: scope,
                   cameraAction: cameraAction)
         }
        let disableSend = amountAvailable.isZero //?? false
        let twoRowButtons = TwoRowButtons(stack: stack.push(),
                                      sendTitle: sendTitle,
                                       sendType: .peerPushDebit,
                                       sendA11y: sendTitle1.tabbed(oneLine: true),
                                      recvTitle: requTitle,
                                       recvType: .peerPullCredit,
                                       recvA11y: requTitle1.tabbed(oneLine: true),
                                 fitsSideBySide: false,
                                      lineLimit: 5,
                                   sendDisabled: disableSend,
                                     sendAction: { controller.frontendState = -1; selectAndUpdate(1)  },
                                     recvAction: { controller.frontendState = 1; selectAndUpdate(2) })
        Group {
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: HSPACING) {
                        twoRowButtons.makeCopy(fitsSideBySide: true)
                    }
//                        .border(.red)
                    VStack { twoRowButtons }
//                        .border(.red)
                }
            } else { // view for iOS 15
                VStack { twoRowButtons }
            }
        }
        .background( Group {
            NavigationLink(destination: sendDest, tag: 1, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
            NavigationLink(destination: requestDest, tag: 2, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
        })
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
