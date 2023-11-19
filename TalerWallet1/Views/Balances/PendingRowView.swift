/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

/// This view shows a pending transaction row in a currency section
struct PendingRowView: View {
    let amount: Amount
    let incoming: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @AppStorage("iconOnly") var iconOnly: Bool = false

    let inTitle0 = String(localized: "TitleIncoming_Short", defaultValue: "Incoming",
                          comment: "Abbreviation of `Pending incoming´ in Balances")
    let inTitle1 = String(localized: "TitleIncoming_Full", defaultValue: "Pending\tincoming",
                          comment: "`Pending incoming´ in Balances - set exactly 1 \t for line break")

    let outTitle0 = String(localized: "TitleOutgoing_Short", defaultValue: "Outgoing",
                           comment: "Abbreviation of `Pending outgoing´ in Balances")
    let outTitle1 = String(localized: "TitleOutgoing_Full", defaultValue: "Pending\toutgoing",
                           comment: "`Pending outgoing´ in Balances - set exactly 1 \t for line break")

    var body: some View {
        let pendingColor = WalletColors().pendingColor(incoming)
        let imageName = incoming ? "plus.diamond"       //  goforward.plus   circle
                                 : "minus.diamond"      //
        let badgeName = needsKYC ? "star.fill"
                                 : "circle.fill"
        let iconBadge = IconBadge(imageName: imageName, foreColor: pendingColor, shouldConfirm: shouldConfirm, needsKYC: needsKYC)

        let inTitle = iconOnly ? inTitle0 : inTitle1
        let outTitle = iconOnly ? outTitle0 : outTitle1
        let pendingTitle = incoming ? inTitle : outTitle

        let currencyInfo = controller.info(for: amount.currencyStr, controller.currencyTicker)
        let amountText = Text(amount.string(currencyInfo))
            .foregroundColor(pendingColor)
            .accessibilityFont(.title2)
            .monospacedDigit()

        // this is the default view for iOS 15
        let vStack = VStack {
            Text(pendingTitle.tabbed(oneLine: true))
            HStack {
                iconBadge
                Spacer(minLength: 0)
                amountText
            }
        }

        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    iconBadge
                    Text(pendingTitle.tabbed(oneLine: false))
                    Spacer(minLength: 0)
                    amountText
                }
                vStack
                VStack {
                    Text(pendingTitle.tabbed(oneLine: true))
                    iconBadge
                    amountText
                }
            }
        } else {
            vStack
        }
    }
}
// MARK: -
#if DEBUG
func PreviewCurrencyInfo(_ currency: String, digits: Int) -> CurrencyInfo {
    let unitName = digits == 0 ? "テ" : "ク"  // do not use real currency symbols like "¥" : "€"
    let scope = ScopeInfo(type: .global, currency: currency)
    let specs = CurrencySpecification(name: currency,
                     fractionalInputDigits: digits,
                    fractionalNormalDigits: digits,
              fractionalTrailingZeroDigits: digits,
                              altUnitNames: [0 : unitName])
    let previewFormatter = CurrencyFormatter.formatter(scope: scope, specs: specs)
    return CurrencyInfo(scope: scope, specs: specs, formatter: previewFormatter)
}

@MainActor
fileprivate struct Preview_Content: View {
    var body: some View {
        let test = Amount(currency: TESTCURRENCY, cent: 123)
        let demo = Amount(currency: DEMOCURRENCY, cent: 123456)
        List {
            PendingRowView(amount: test, incoming: true, shouldConfirm: true, needsKYC: false)
            PendingRowView(amount: demo, incoming: false, shouldConfirm: false, needsKYC: true)
        }
    }
}
fileprivate struct Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
//        @StateObject private var controller = Controller.shared
        var body: some View {
            Text("Hello")
//            Preview_Content()
//                .environmentObject(controller)
        }
    }
    static var previews: some View {
        StateContainer()
    }
}
#endif
