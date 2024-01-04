/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct BalanceButton: View {
    let amountStr: String
    let sizeCategory: ContentSizeCategory
    let rowAction: () -> Void
    let balanceDest: LazyView<TransactionsListView>?

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("iconOnly") var iconOnly: Bool = false

    /// Renders the Balance button. "Balance" leading, amountStr trailing. If it doesn't fit in one row then
    /// amount (trailing) goes underneath "Balance" (leading).
    var body: some View {
        let amountText = Text(amountStr)
            .accessibilityFont(.title)
            .foregroundColor(.primary)
            .monospacedDigit()
        let hLayout = HStack(spacing: 0) {
                Spacer(minLength: 0)
                amountText
            }
        let balanceCell = Group {
            if iconOnly {
                hLayout
            } else {
                let balanceText = Text("Balance:", comment: "Main view")
                    .accessibilityFont(.title2)
                    .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
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
#if TABBAR  // Taler Wallet
        NavigationLink { balanceDest } label: {
            balanceCell
                .accessibilityElement(children: .combine)
                .accessibilityHint("Will go to main transactions list.")
        }
#else       // GNU Taler
        Button(action: rowAction) {
            balanceCell
        }   .disabled(false)
            .buttonStyle(TalerButtonStyle(type: iconOnly ? .plain : .balance, aligned: .trailing))
            .accessibilityElement(children: .combine)
            .accessibilityHint("Will go to main transactions list.")
//            .accessibilityLabel(balanceTitleStr + " " + amountStr)    // TODO: CurrencyFormatter!
#endif
    }
}


/// This view shows the currency row in a currency section, and two action buttons below
///  Balance:               amount
/// [Send Money]  [Request Payment]
struct BalanceRowView: View {
    let stack: CallStack
    let amount: Amount
    let sendAction: () -> Void
    let recvAction: () -> Void
    let rowAction: () -> Void
    let balanceDest: LazyView<TransactionsListView>?

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @AppStorage("iconOnly") var iconOnly: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let sendTitle0 = String(localized: "SendButton_Short", defaultValue: "Send",
                              comment: "Abbreviation of button `Send Money´")
    let sendTitle1 = String(localized: "SendButton_Full", defaultValue: "Send\tMoney",
                              comment: "`Send Money´ in Balances - set exactly 1 \\t for line break")

    let requestTitle0 = String(localized: "RequestButton_Short", defaultValue: "Request",
                                 comment: "Abbreviation of button `Request Payment´")
    let requestTitle1 = String(localized: "RequestButton_Full", defaultValue: "Request\tPayment",
                                 comment: "`Request Payment´ in Balances - set exactly 1 \\t for line break")
    var body: some View {
        VStack (alignment: .trailing, spacing: 6) {
            let currencyInfo = controller.info(for: amount.currencyStr, controller.currencyTicker)
            let amountStr = amount.string(currencyInfo)
            BalanceButton(amountStr: amountStr,
                       sizeCategory: sizeCategory,
                          rowAction: rowAction,
                        balanceDest: balanceDest)
//            .border(.red)

            let sendTitle = iconOnly ? sendTitle0 : sendTitle1
            let requTitle = iconOnly ? requestTitle0 : requestTitle1
            let twoRowButtons = TwoRowButtons(sendTitle: sendTitle,
                                              recvTitle: requTitle,
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
//        let testStr = test.string(testInfo)
//        let demoStr = demo.string(demoInfo)

        List {
            Section {
                BalanceRowView(stack: CallStack("Preview"), amount: demo,
                          sendAction: {}, recvAction: {}, rowAction: {}, balanceDest: nil)
            }
            BalanceRowView(stack: CallStack("Preview"), amount: test, 
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
