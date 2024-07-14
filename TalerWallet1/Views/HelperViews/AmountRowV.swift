/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

// Title and Amount
struct AmountRowV: View {
    let title: String
    let amount: Amount
    let isNegative: Bool        // if true, show a "-" before the amount
    let color: Color
    let large: Bool      // set to false for QR or IBAN

    var body: some View {
        let titleV = Text(title)
                        .multilineTextAlignment(.leading)
                        .talerFont(.body)
        let amountV = AmountV(amount: amount, isNegative: isNegative, large: large)
                        .foregroundColor(color)
        let verticalV = VStack(alignment: .leading) {
            titleV
            HStack(alignment: .lastTextBaseline) {
                Spacer(minLength: 2)
                amountV
            }
        }
        Group {
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .lastTextBaseline) {
                        titleV//.border(.orange)
                        Spacer(minLength: 2)
                        amountV//.border(.gray)
                    }
                    HStack(alignment: .lastTextBaseline) {
                        titleV//.border(.blue)
                            .lineLimit(2, reservesSpace: true)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 2)
                        amountV//.border(.gray)
                    }
                    verticalV
                }
            } else { // view for iOS 15
                verticalV
            }
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .listRowSeparator(.hidden)
    }
}
extension AmountRowV {
    init(title: String, amount: Amount, isNegative: Bool, color: Color) {
        self.title = title
        self.amount = amount
        self.isNegative = isNegative
        self.color = color
        self.large = true
    }
}

// MARK: -
fileprivate func talerFromStr(_ from: String) -> Amount {
    do {
        let amount = try Amount(fromString: from)
        return amount
    } catch {
        return Amount(currency: "Taler", cent: 480)
    }
}
#Preview {
    List {
        let fee = Amount(currency: "Taler", cent: 20)
        AmountRowV(title: "Fee", amount: fee, isNegative: true, color: Color("Outgoing"), large: false)
        let cents = Amount(currency: "Taler", cent: 480)
        AmountRowV(title: "Cents", amount: cents, isNegative: false, color: Color("Incoming"))
        let amount = talerFromStr("Taler:4.80")
        AmountRowV(title: "Chosen amount to withdraw", amount: amount, isNegative: false, color: Color("Incoming"))
    }
}
