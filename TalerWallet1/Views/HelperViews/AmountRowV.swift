/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

// Title and Amount
struct AmountRowV: View {
    let stack: CallStack?
    let title: String
    let amount: Amount
    let scope: ScopeInfo?
    let isNegative: Bool?        // show fee with minus (or plus) sign, or no sign if nil
    let color: Color
    let large: Bool      // set to false for QR or IBAN

    var body: some View {
        let titleV = Text(title)
                        .multilineTextAlignment(.leading)
                        .talerFont(.body)
        let amountV = AmountV(stack: stack?.push(),
                              scope: scope,
                             amount: amount,
                         isNegative: isNegative,
                      strikethrough: false,
                              large: large)
                        .foregroundColor(color)
        let verticalV = VStack(alignment: .leading) {
            titleV
            HStack(alignment: .lastTextBaseline) {
                Spacer(minLength: 2)
                amountV
            }
        }
        Group {
            if #available(iOS 16.4, *) {
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
    init(_ title: String, amount: Amount, scope: ScopeInfo?, isNegative: Bool, color: Color) {
        self.stack = nil
        self.title = title
        self.amount = amount
        self.scope = scope
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

#if DEBUG
@MainActor
fileprivate struct BindingViewContainer: View {
    @State private var previewD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
    var body: some View {
        let scope = ScopeInfo.zero(DEMOCURRENCY)
        let fee = Amount(currency: DEMOCURRENCY, cent: 20)
        AmountRowV("Fee", amount: fee, scope: scope, isNegative: true, color: Color("Outgoing"))
        let cents = Amount(currency: DEMOCURRENCY, cent: 480)
        AmountRowV("Cents", amount: cents, scope: scope, isNegative: false, color: Color("Incoming"))
        let amount = talerFromStr("Taler:4.80")
        AmountRowV("Chosen amount to withdraw", amount: amount, scope: scope, isNegative: false, color: Color("Incoming"))
    }
}

#Preview {
    List {
        BindingViewContainer()
    }
}
#endif
