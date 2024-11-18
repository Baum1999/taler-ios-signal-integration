/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

/// This view shows a pending transaction row in a currency section
struct PendingRowView: View {
    let scope: ScopeInfo
    let amount: Amount
    let incoming: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool

//    @Environment(\.sizeCategory) var sizeCategory
    @AppStorage("minimalistic") var minimalistic: Bool = false

    let inTitle0 = String(localized: "TitleIncoming_Short", defaultValue: "Incoming",
                          comment: "Abbreviation of `Pending incoming´ in Balances")
    let inTitle1 = String(localized: "TitleIncoming_Full", defaultValue: "Pending\tincoming",
                          comment: "`Pending incoming´ in Balances - set exactly 1 \\t for line break")

    let outTitle0 = String(localized: "TitleOutgoing_Short", defaultValue: "Outgoing",
                           comment: "Abbreviation of `Pending outgoing´ in Balances")
    let outTitle1 = String(localized: "TitleOutgoing_Full", defaultValue: "Pending\toutgoing",
                           comment: "`Pending outgoing´ in Balances - set exactly 1 \\t for line break")

    var body: some View {
        let pendingColor = WalletColors().pendingColor(incoming)
        let iconBadge = PendingIconBadge(foreColor: pendingColor, done: false, incoming: incoming,
                                     shouldConfirm: shouldConfirm, needsKYC: needsKYC)
        let inTitle = minimalistic ? inTitle0 : inTitle1
        let outTitle = minimalistic ? outTitle0 : outTitle1
        let pendingTitle = incoming ? inTitle : outTitle

        let amountText = AmountV(scope, amount, isNegative: !incoming)
            .foregroundColor(pendingColor)

        // this is the default view for iOS 15
        let vLayout = VStack {
            Text(pendingTitle.tabbed(oneLine: true))
            HStack {
                iconBadge
                amountText.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }

        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    iconBadge
                    Text(pendingTitle.tabbed(oneLine: false))
                    amountText.frame(maxWidth: .infinity, alignment: .trailing)
                }
                vLayout
                VStack {
                    Text(pendingTitle.tabbed(oneLine: true))
                    iconBadge
                    amountText
                }
            }
        } else {
            vLayout
        }
    }
}
// MARK: -
#if DEBUG
//@MainActor
//fileprivate struct Preview_Content: View {
//    @State private var previewD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
//    @State private var previewT: CurrencyInfo = CurrencyInfo.zero(TESTCURRENCY)
//    var body: some View {
//        let test = Amount(currency: TESTCURRENCY, cent: 123)
//        let demo = Amount(currency: DEMOCURRENCY, cent: 123456)
//        List {
//            PendingRowView(amount: test, incoming: true, shouldConfirm: true, needsKYC: false)
//            PendingRowView(amount: demo, incoming: false, shouldConfirm: false, needsKYC: true)
//        }
//    }
//}
//fileprivate struct Previews: PreviewProvider {
//    @MainActor
//    struct StateContainer: View {
////        @StateObject private var controller = Controller.shared
//        var body: some View {
//            let hello = "Hello"
//            Text(hello)
////            Preview_Content()
////                .environmentObject(controller)
//        }
//    }
//    static var previews: some View {
//        StateContainer()
//    }
//}
#endif
