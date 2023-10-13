/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

/// This view shows the currency row in a currency section
/// [Send Coins]  [Receive Coins]     Balance

struct BalanceButton: View {
    let amount: Amount
    let rowAction: () -> Void

    var body: some View {
        Button(action: rowAction) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("Balance", comment: "Balance in main view")
                    .bold()         // in iOS-15 defined for Text, but not for Font (only iOS-16)
                Text(verbatim: "\(amount.valueStr)")  // TODO: CurrencyFormatter?
                    .accessibilityFont(.title)
                    .monospacedDigit()
            }
            .accessibilityFont(.subheadline)
        }   .disabled(false)
            .accessibilityElement(children: /*@START_MENU_TOKEN@*/.ignore/*@END_MENU_TOKEN@*/)
            .accessibilityLabel("Balance \(amount.readableDescription)")    // TODO: CurrencyFormatter!
            .buttonStyle(TalerButtonStyle(type: .plain, aligned: .trailing))
//                .background(Color.yellow)
    }
}

struct BalanceRowView: View {
    let amount: Amount
    let sendAction: () -> Void
    let recvAction: () -> Void
    let rowAction: () -> Void
    @Environment(\.sizeCategory) var sizeCategory
    let sendTitle1 = String(localized: "Send", comment: "Top of button <Send Money>")
    let sendTitle2 = String(localized: "Money", comment: "Bottom of button <Send Money>")
    let requestTitle1 = String(localized: "Request", comment: "Top of button <Request Payment>")
    let requestTitle2 = String(localized: "Payment", comment: "Bottom of button <Request Payment>")

    func needVStack(_ amount: Amount) -> Bool {
        // Sizes: 320 (SE), 375 (X, Xs, 12, 13 mini), 390 (12,13,14), 414 (Plus, Max), 428 (Pro Max)
        guard 350 < UIScreen.screenWidth else {return true}   // always for iPhone SE 1st Gen
        var count = amount.currencyStr.count
//        print(sizeCategory)
        switch sizeCategory {
            case ContentSizeCategory.extraSmall:
                count += 0
            case ContentSizeCategory.small:
                count += 1
            case ContentSizeCategory.medium:
                count += 2
            case ContentSizeCategory.large:
                count += 3
            case ContentSizeCategory.extraLarge:
                count += 4
            default:
                count += 5
        }
        return count > 9
    }

    var body: some View {
        Group {
            let requestTitle = requestTitle1 + "\n" + requestTitle2
            let sendTitle = sendTitle1 + "\n" + sendTitle2
            if needVStack(amount) {
                VStack (alignment: .trailing) {
                    BalanceButton(amount: amount, rowAction: rowAction)
                    HStack {
                    }
                    TwoRowButtons(sendTitle: sendTitle, recvTitle: requestTitle,
                                  lineLimit: 5, sendDisabled: amount.isZero,
                                  sendAction: sendAction, recvAction: recvAction)
                }
            } else {
                HStack {
                    BalanceButton(amount: amount, rowAction: rowAction)
                    TwoRowButtons(sendTitle: sendTitle, recvTitle: requestTitle,
                                  lineLimit: 5, sendDisabled: amount.isZero,
                                  sendAction: sendAction, recvAction: recvAction)
                }
//                .fixedSize(horizontal: true, vertical: true)   // should make all buttons equal height - but doesn't
            }
        }
        .accessibilityElement(children: .combine)
    }
}
// MARK: -
#if DEBUG
struct BalanceRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            BalanceRowView(amount: try! Amount(fromString: TESTCURRENCY + ":1234.56"),
                           sendAction: {}, recvAction: {}, rowAction: {})
            BalanceRowView(amount: try! Amount(fromString: DEMOCURRENCY + ":1234.56"),
                           sendAction: {}, recvAction: {}, rowAction: {})
        }
    }
}
#endif
