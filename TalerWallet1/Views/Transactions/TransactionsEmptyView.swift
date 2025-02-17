/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

/// This view shows hints if a wallet is empty
/// It is the very first thing the user sees after installing the app

struct TransactionsEmptyView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let currency: String

    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    var body: some View {
        List {
            Section {
                Text("There are no transactions for \(currency).")
            }
            .talerFont(.title2)
        }
        .listStyle(myListStyle.style).anyView
//        .padding(.vertical)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_EMPTY_HISTORY, stack: stack.push())     // 20
        }
    }
}

struct TransactionsEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsEmptyView(stack: CallStack("Preview"), currency: LONGCURRENCY)
    }
}
