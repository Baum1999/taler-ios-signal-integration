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
    @AppStorage("iconOnly") var iconOnly: Bool = false

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


//    func
    func titles(_ title: String) -> (String, String?) {
        if let separatorIndex = title.firstIndex(of: "\n") {
            let title1 = String(title[..<separatorIndex])
            let title2 = String(title[title.index(separatorIndex, offsetBy: 1)...])
            return (title1, title2)
        }
        return (title, nil)
    }

    func titles(_ titles: (String, String?), uiFont: UIFont) -> [(String, UIFont)] {
        let (title1, title2) = titles
        if let title2 {
            return [(title1, uiFont), (title2, uiFont)]
        }
        return [(title1, uiFont)]
    }

    var body: some View {
        let depositTitle0 = String(localized: "Deposit", comment: "Abbreviation <Deposit (currency)>")
        let depositTitle1 = String(localized: "Deposit\n\(currency)",
                                   comment: "Button <Deposit (currency)>, must have ONE \n and ONE %s")
        let withdrawTitle0 = String(localized: "Withdraw", comment: "Abbreviation <Withdraw (currency)>")
        let withdrawTitle1 = String(localized: "Withdraw\n\(currency)",
                                    comment: "Button <Withdraw (currency)>, must have ONE \n and ONE %s")
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
                let (deposit1, deposit2) = titles(depositTitle1)
                let (withdraw1, withdraw2) = titles(withdrawTitle1)
                let titles = iconOnly ? [(depositTitle0, uiFont), (withdrawTitle0, uiFont)]
                                      : titles((deposit1, deposit2), uiFont: uiFont) +
                                        titles((withdraw1, withdraw2), uiFont: uiFont)
                let fitsSideBySide = Self.fitsSideBySide(titles, availableWidth: width,
                                                         sizeCategory: sizeCategory, padding: 10)
                                                                                    // TODO:  amount.currencyStr
                let twoRowButtons = TwoRowButtons(sendTitles: iconOnly ? (depositTitle0, nil)  : (deposit1, deposit2),
                                                  recvTitles: iconOnly ? (withdrawTitle0, nil) : (withdraw1, withdraw2),
                                              fitsSideBySide: fitsSideBySide,
                                                   lineLimit: 5,
                                                sendDisabled: true,             // TODO: availableAmount.isZero
                                                  sendAction: { selectAndUpdate(1) },
                                                  recvAction: { selectAndUpdate(2) })
                if fitsSideBySide {
                    HStack(spacing: HSPACING) { twoRowButtons }
                } else {
                    VStack { twoRowButtons }
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
