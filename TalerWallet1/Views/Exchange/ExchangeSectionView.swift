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
        // while navigation animation runs, contact Exchange to update Fees
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
                let spacing = CGFloat(10)                  // space between the two buttons
                if Self.needVStack(titles, width: width, spacing: spacing) {
                    VStack { twoRowButtons }
                } else {
                    HStack(spacing: spacing) { twoRowButtons }
                }
            }
        }
    }
}
// MARK: -
/// This view shows the currency name in an exchange section
///         currency
/// [Deposit Coins]  [Withdraw Coins]
struct ExchangeSectionView: View {
    let stack: CallStack
//    let amount: Amount
    let currency: String          // TODO: amount.currencyStr
    let exchanges: [Exchange]
    @Binding var centsToTransfer: UInt64

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Section {
            ForEach(exchanges) { exchange in
                ExchangeRowView(stack: stack.push(),
                             exchange: exchange,
//                               amount: amount,
                             currency: currency,            // TODO: (balance.available) amount.isZero to disable Deposit-button
                      centsToTransfer: $centsToTransfer)
            }
            .accessibilityElement(children: .combine)
        } header: {
            BarGraphHeader(stack: stack.push(), currency: currency)
        }
    }
}
// MARK: -
#if DEBUG
struct ExchangeRow_Container : View {
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
        ExchangeSectionView(stack: CallStack("Preview"), currency: LONGCURRENCY,
                            exchanges: [exchange1, exchange2],
                            centsToTransfer: $centsToTransfer)
    }
}

struct ExchangeRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ExchangeRow_Container()
        }
    }
}
#endif
