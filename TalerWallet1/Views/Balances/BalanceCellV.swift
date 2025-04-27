/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

struct BalanceCellV: View {
    let stack: CallStack
    let scope: ScopeInfo
    let amount: Amount
//    let sizeCategory: ContentSizeCategory
//    let rowAction: () -> Void
    let balanceDest: TransactionsListView

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    private func baseURL(_ url: String?) -> String {
        if let url {
            return url.trimURL
        } else {
            return String(localized: "Unknown payment service", comment: "exchange url")
        }
    }

    /// Renders the Balance button. "Balance" leading, amountStr trailing. If it doesn't fit in one row then
    /// amount (trailing) goes underneath "Balance" (leading).
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
#if DEBUG
        let debug = 1==0
        let red = debug ? Color.red : Color.clear
        let green = debug ? Color.green : Color.clear
        let blue = debug ? Color.blue : Color.clear
        let orange = debug ? Color.orange : Color.clear
#endif
        let amountV = AmountV(stack: stack.push("AmountV"),
                              scope: scope,
                             amount: amount,
                         isNegative: nil,           // don't show the + sign
                      strikethrough: false,
                              large: true)
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

                if #available(iOS 16.4, *) {
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
                .accessibilityHint(String(localized: "Will go to main transactions list.", comment: "a11y"))
//            .accessibilityLabel(balanceTitleStr + SPACE + amountStr)    // TODO: CurrencyFormatter!
        }
    }
}

// MARK: -
#if  false
struct BalanceCellV_Previews: PreviewProvider {
    @MainActor
  struct StateContainer: View {
    var body: some View {
        let test = Amount(currency: TESTCURRENCY, cent: 123)
        let demo = Amount(currency: DEMOCURRENCY, cent: 123456)

        List {
            Section {
                BalanceCellV(stack: CallStack("Preview"), currencyName: DEMOCURRENCY, amount: demo,
                          sendAction: {}, recvAction: {}, rowAction: {}, balanceDest: nil)
            }
            BalanceCellV(stack: CallStack("Preview"), currencyName: TESTCURRENCY, amount: test,
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
