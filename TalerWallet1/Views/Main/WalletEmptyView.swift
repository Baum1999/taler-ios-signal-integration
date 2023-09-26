/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

/// This view shows hints if a wallet is empty
/// It is the very first thing the user sees after installing the app

struct WalletEmptyView: View {
    private let symLog = SymLogV(0)
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    var body: some View {
        List {
            Section {
                Text("There is no digital cash in your wallet.")
                    .accessibilityFont(.title3)
                    .listRowSeparator(.hidden)
                Link("Get some test money", destination: URL(string: DEMOBANK)!)
                    .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, aligned: .center))
                    .padding(.vertical)
            }
            Section {
                Text("Just register a test account in the demo bank, then withdraw some electronic cash.")
                    .accessibilityFont(.body)
            }
        }
        .listStyle(myListStyle.style).anyView
        .accessibilityFont(.title2)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_EMPTY)     // 10
        }
    }
}

struct WalletEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        WalletEmptyView()
    }
}
