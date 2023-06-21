/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

/// This view shows an uncompleted transaction row in a currency section
struct UncompletedRowView: View {
    @Binding var uncompletedTransactions: [Transaction]

    var body: some View {
        let count = uncompletedTransactions.count
        HStack {
            Spacer()
            Text("\(count) uncompleted transactions")
                .font(.title2)
                .foregroundColor(WalletColors().uncompletedColor)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
// MARK: -
#if DEBUG
//struct UncompletedRowView_Previews: PreviewProvider {
//    static var previews: some View {
//        let uncompletedTransactions: [Transaction] = []
//        List {
//            UncompletedRowView(uncompletedTransactions: uncompletedTransactions)
//        }
//    }
//}
#endif
