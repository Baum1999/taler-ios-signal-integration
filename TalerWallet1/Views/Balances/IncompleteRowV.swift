/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

/// This view shows an incompleteTransactions row in a currency section, below the balance
struct IncompleteRowV: View {
    @Binding var incompleteTransactions: [Transaction]

    var body: some View {
        let count = incompleteTransactions.count
        HStack {
            Spacer()
            Text("\(count) incomplete transactions")
                .accessibilityFont(.title2)
                .foregroundColor(WalletColors().incompleteColor)
            Spacer()
        }
    }
}
// MARK: - Preview
#if DEBUG
fileprivate struct IncompleteRowContainer: View {
    @State var incompleteTransactions: [Transaction] = []

    var body: some View {
        IncompleteRowV(incompleteTransactions: $incompleteTransactions)
    }
}
struct IncompleteRowV_Previews: PreviewProvider {
    static var previews: some View {
        List {
            IncompleteRowContainer()
        }
    }
}
#endif
