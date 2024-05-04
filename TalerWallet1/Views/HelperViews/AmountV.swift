/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct AmountV: View {
    let amount: Amount
    let large: Bool      // set to false for QR or IBAN

    @EnvironmentObject private var controller: Controller

    var body: some View {
        Text(amount.string())
            .multilineTextAlignment(.center)
            .talerFont(large ? .title : .title2)
//            .fontWeight(large ? .medium : .regular)       // @available(iOS 16.0, *)
            .monospacedDigit()
            .accessibilityLabel(amount.readableDescription)
    }
}
extension AmountV {
    init(_ amount: Amount) {
        self.amount = amount
        self.large = false
    }
}
// MARK: -
//#Preview {
//    AmountV()
//}
