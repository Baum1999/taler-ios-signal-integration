/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct ExchangeRowView: View {
    let stack: CallStack
    let exchange: Exchange
    let currency: String
    @Binding var amountToTransfer: Amount

    @Environment(\.sizeCategory) var sizeCategory
    @AppStorage("iconOnly") var iconOnly: Bool = false
    @State private var buttonSelected: Int? = nil

    func selectAndUpdate(_ button: Int) {
        buttonSelected = button      // will trigger NavigationLink
        // TODO: after user tapped a button, while navigation animation runs, contact Exchange to update Fees
        // cannot be uncommented yet since there is no scopeInfo
//        Task { // runs on MainActor
//            do {
//                try await model.updateExchange(scopeInfo: balance.scopeInfo)
//            } catch {    // TODO: error handling - couldn't updateExchange
//                //                symLog.log("error: \(error)")
//            }
//        }
    }

    var body: some View {
        let depositTitle0 = String(localized: "DepositButton_Short", defaultValue: "Deposit",
                                   comment: "Abbreviation of `Deposit (currency)´")
        let depositTitle1 = String(localized: "Deposit\t\(currency)",
                                   comment: "Button `Deposit (currency)´, must have ONE \\t and ONE %@")

        let withdrawTitle0 = String(localized: "WithdrawButton_Short", defaultValue: "Withdraw",
                                    comment: "Abbreviation of `Withdraw (currency)´")
        let withdrawTitle1 = String(localized: "Withdraw\t\(currency)",
                                    comment: "Button `Withdraw (currency)´, must have ONE \\t and ONE %@")
        let baseURL = exchange.exchangeBaseUrl

        HStack(spacing: 0) {    // can't use the built in Label because it adds the accessory arrow
            Text(baseURL.trimURL())
                .accessibilityFont(.body)
            NavigationLink(destination: LazyView {
                EmptyView()     // TODO: Deposit
            }, tag: 1, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0)
            NavigationLink(destination: LazyView {
                ManualWithdraw(stack: stack.push(),
                            exchange: exchange,
                    amountToTransfer: $amountToTransfer)
            }, tag: 2, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0)
        }.listRowSeparator(.hidden)

        let depositTitle = iconOnly ? depositTitle0 : depositTitle1
        let withdrawTitle = iconOnly ? withdrawTitle0 : withdrawTitle1
        let twoRowButtons = TwoRowButtons(sendTitle: depositTitle,
                                          recvTitle: withdrawTitle,
                                     fitsSideBySide: false,
                                          lineLimit: 5,
                                       sendDisabled: true,             // TODO: availableAmount.isZero
                                         sendAction: { selectAndUpdate(1) },
                                         recvAction: { selectAndUpdate(2) })
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
// MARK: -
#if DEBUG
fileprivate struct ExchangeRow_Container : View {
    @State private var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 1234)

//    let amount = Amount(currency: LONGCURRENCY, cent: 123456)
    var body: some View {
        let exchange1 = Exchange(exchangeBaseUrl: ARS_AGE_EXCHANGE,
                                        currency: LONGCURRENCY,
                                       paytoUris: [],
                                       tosStatus: .pending,
                             exchangeEntryStatus: .preset,
                            exchangeUpdateStatus: .initial,
                           ageRestrictionOptions: [12,16])
        let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                        currency: LONGCURRENCY,
                                       paytoUris: [],
                                       tosStatus: .proposed,
                             exchangeEntryStatus: .ephemeral,
                            exchangeUpdateStatus: .ready,
                           ageRestrictionOptions: [])
        ExchangeRowView(stack: CallStack("Preview"),
                     exchange: exchange1,
                     currency: LONGCURRENCY,
             amountToTransfer: $amountToTransfer)
    }
}

fileprivate struct ExchangeRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ExchangeRow_Container()
        }
    }
}
#endif
