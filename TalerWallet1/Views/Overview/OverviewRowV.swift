/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct CurrenciesCell: View {
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
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
        let amountV = AmountV(stack: stack.push(), currencyInfo: $currencyInfo, amount: amount, isNegative: false, large: true)
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
struct OverviewRowV: View {
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
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
        VStack (alignment: .trailing, spacing: 6) {
            CurrenciesCell(stack: stack.push(),
                    currencyInfo: $currencyInfo,
                          amount: amount,
                    sizeCategory: sizeCategory,
                       rowAction: rowAction,
                     balanceDest: balanceDest)
//            .border(.red)
        }
    }
}
// MARK: -
#if  DEBUG
struct OverviewRowV_Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
        @State private var currencyInfoD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
        @State private var currencyInfoT: CurrencyInfo = CurrencyInfo.zero(TESTCURRENCY)

        var body: some View {
            let test = Amount(currency: TESTCURRENCY, cent: 123)
            let demo = Amount(currency: DEMOCURRENCY, cent: 123456)

            List {
                Section {
                    OverviewRowV(stack: CallStack("Preview"), currencyInfo: $currencyInfoD, amount: demo,
                            sendAction: {}, recvAction: {}, rowAction: {}, balanceDest: nil)
                }
                OverviewRowV(stack: CallStack("Preview"), currencyInfo: $currencyInfoT, amount: test,
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
