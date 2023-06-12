/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

/// This view shows hints if a wallet is empty
/// It is the very first thing the user sees after installing the app

struct TransactionsEmptyView: View {
    private let symLog = SymLogV()
    @AppStorage("listStyle") var myListStyle = MyListStyle.automatic

    let currency: String

    var body: some View {
        List {
            Section {
                Text("There are no transactions for \(currency).")
            }
        }
        .padding(.vertical)
        .font(.title2)
        .listStyle(myListStyle.style)
        .anyView
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_EMPTY)     // 10
        }
    }
}

struct TransactionsEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsEmptyView(currency: LONGCURRENCY)
    }
}
