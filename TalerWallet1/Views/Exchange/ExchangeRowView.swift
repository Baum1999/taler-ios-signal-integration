/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct ExchangeRowView: View {
    let stack: CallStack
    let exchange: Exchange
//    let amount: Amount
    let currency: String
    @Binding var centsToTransfer: UInt64

    @Environment(\.sizeCategory) var sizeCategory
    @State private var buttonSelected: Int? = nil

    func selectAndUpdate(_ button: Int) {
        buttonSelected = button      // will trigger NavigationLink
        // TODO: while navigation animation runs, contact Exchange to update Fees
//        Task { // runs on MainActor
//            do {
//                try await model.updateExchange(scopeInfo: balance.scopeInfo)
//            } catch {    // TODO: error handling - couldn't updateExchange
//                //                symLog.log("error: \(error)")
//            }
//        }
    }

    let depositTitle = String(localized: "Deposit", comment: "Top of button <Deposit (currency)>")
    let withdrawTitle = String(localized: "Withdraw", comment: "Top of button <Withdraw (currency)>")

    var body: some View {
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
                     centsToTransfer: $centsToTransfer)
            }, tag: 2, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0)
        }.listRowSeparator(.hidden)

        SingleAxisGeometryReader { width in
            Group {
                let uiFont = TalerFont.uiFont(.title3)
                let titles = [(depositTitle, uiFont), (withdrawTitle, uiFont), (currency, uiFont)]
                let sendTitle = depositTitle + "\n" + currency                          // TODO:  amount.currencyStr
                let recvTitle = withdrawTitle + "\n" + currency                         // TODO:  amount.currencyStr
                let twoRowButtons = TwoRowButtons(sendTitle: sendTitle, recvTitle: recvTitle,
                                                  lineLimit: 5, sendDisabled: true,     // TODO: amount.isZero
                                                 sendAction: { selectAndUpdate(1) },
                                                 recvAction: { selectAndUpdate(2) })
                if Self.needVStack(titles, width: width, correctForSize: 1.0, spacing: HSPACING + 4) {
                    VStack { twoRowButtons }
                } else {
                    HStack(spacing: HSPACING) { twoRowButtons }
                }
            }
        }
    }
}

// MARK: -
#if DEBUG
fileprivate struct ExchangeRow_Container : View {
    @State private var centsToTransfer: UInt64 = 100

//    let amount = try! Amount(fromString: LONGCURRENCY + ":1234.56")
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
              centsToTransfer: $centsToTransfer)
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
