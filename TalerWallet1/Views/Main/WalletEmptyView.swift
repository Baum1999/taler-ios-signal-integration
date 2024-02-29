/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

/// This view shows hints if a wallet is empty
/// It is the very first thing the user sees after installing the app

struct WalletEmptyView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    var body: some View {
        List {
            Section {
                Text("There is no digital cash in your wallet.")
                    .talerFont(.title3)
            }
            Section {
                Text("You can register an account in the demo bank, then withdraw some digital cash to experience how to pay with the money of the future.")
                    .talerFont(.body)
                    .listRowSeparator(.hidden)
                let title = String(localized: "LinkTitle_Test_Money", defaultValue: "Get demo money")
                Link(title, destination: URL(string: DEMOBANK)!)
                    .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, aligned: .center))
                    .padding(.vertical)
                    .accessibilityHint("Will go to the demo bank website.")
            }
            Section {
                Text("Use the QR code scan button to start a withdrawal if your bank already supports Taler payments.")
                    .talerFont(.body)
                    .listRowSeparator(.hidden)
                Text("You can also add a payment service manually on the Banking tab.")
                    .talerFont(.body)
            }
        }
        .listStyle(myListStyle.style).anyView
        .talerFont(.title2)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_EMPTY_WALLET, stack: stack.push("onAppear"))     // 10
        }
    }
}

struct WalletEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        WalletEmptyView(stack: CallStack("Preview"))
    }
}
