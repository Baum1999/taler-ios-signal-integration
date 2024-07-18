/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct BalanceCell: View {
    let stack: CallStack?
    let amount: Amount
    let sizeCategory: ContentSizeCategory
    let rowAction: () -> Void
    let balanceDest: LazyView<TransactionsListView>?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    /// Renders the Balance button. "Balance" leading, amountStr trailing. If it doesn't fit in one row then
    /// amount (trailing) goes underneath "Balance" (leading).
    var body: some View {
        let amountV = AmountV(stack: stack?.push("AmountV"), amount: amount, isNegative: false, large: true)
            .foregroundColor(.primary)
        let hLayout = amountV
                        .frame(maxWidth: .infinity, alignment: .trailing)
        let balanceCell = Group {
            if minimalistic {
                hLayout
            } else {
                let balanceText = Text("Balance:", comment: "Main view")
                    .talerFont(.title2)
                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                let vLayout = VStack(alignment: .leading, spacing: 0) {
                    balanceText
                    hLayout
                }

                if #available(iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: HSPACING) {
                            balanceText
                            hLayout
                        }
                        vLayout
                    }
                } else { vLayout } // view for iOS 15
            }
        }
        NavigationLink { balanceDest } label: {
            balanceCell
                .accessibilityElement(children: .combine)
                .accessibilityHint(String(localized: "Will go to main transactions list."))
//            .accessibilityLabel(balanceTitleStr + " " + amountStr)    // TODO: CurrencyFormatter!
        }
    }
}


/// This view shows the currency row in a currency section, and two action buttons below
///  Balance:               amount
/// [Send Money]  [Request Payment]
struct BalanceRowView: View {
    let stack: CallStack
    let currencyName: String
    let amount: Amount
    let sendAction: () -> Void
    let recvAction: () -> Void
    let rowAction: () -> Void
    let balanceDest: LazyView<TransactionsListView>?

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    var body: some View {
        let sendTitle0 = String(localized: "SendButton_Short", defaultValue: "Send",
                                  comment: "Abbreviation of button `Send (currency)´")
        let sendTitle1 = String(localized: "SendButton_Full", defaultValue: "Send\t\(currencyName)",
                                  comment: "`Send (currency)´ in Balances - must have ONE \\t and ONE %@")

        let requestTitle0 = String(localized: "RequestButton_Short", defaultValue: "Request",
                                     comment: "Abbreviation of button `Request (currency)´")
        let requestTitle1 = String(localized: "RequestButton_Full", defaultValue: "Request\t\(currencyName)",
                                     comment: "`Request (currency)´ in Balances - must have ONE \\t and ONE %@")
        VStack (alignment: .trailing, spacing: 6) {
            BalanceCell(stack: stack.push("BalanceCell"),
                       amount: amount,
                 sizeCategory: sizeCategory,
                    rowAction: rowAction,
                  balanceDest: balanceDest)
//            .border(.red)

            let sendTitle = minimalistic ? sendTitle0 : sendTitle1
            let requTitle = minimalistic ? requestTitle0 : requestTitle1
            let twoRowButtons = TwoRowButtons(stack: stack.push(),
                                          sendTitle: sendTitle,
                                           sendType: .peerPushDebit,
                                           sendA11y: sendTitle.tabbed(oneLine: true),
                                          recvTitle: requTitle,
                                           recvType: .peerPullCredit,
                                           recvA11y: requTitle.tabbed(oneLine: true),
                                     fitsSideBySide: false,
                                          lineLimit: 5,
                                       sendDisabled: amount.isZero,
                                         sendAction: sendAction,
                                         recvAction: recvAction)
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
    }
}
// MARK: -
#if  DEBUG
struct BalanceRowView_Previews: PreviewProvider {
    @MainActor
  struct StateContainer: View {
    var body: some View {
        let test = Amount(currency: TESTCURRENCY, cent: 123)
        let demo = Amount(currency: DEMOCURRENCY, cent: 123456)

        List {
            Section {
                BalanceRowView(stack: CallStack("Preview"), currencyName: DEMOCURRENCY, amount: demo,
                          sendAction: {}, recvAction: {}, rowAction: {}, balanceDest: nil)
            }
            BalanceRowView(stack: CallStack("Preview"), currencyName: TESTCURRENCY, amount: test,
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
