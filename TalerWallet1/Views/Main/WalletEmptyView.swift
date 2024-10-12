/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import taler_swift

/// This view shows hints if a wallet is empty
/// It is the very first thing the user sees after installing the app

struct WalletEmptyView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @State private var withDrawDisabled = false

    var body: some View {
        List {
            Section {
                Text("There is no digital cash in your wallet yet.")
                    .talerFont(.title3)
            }
            Section {
                let qrButton = Image(systemName: "qrcode.viewfinder")
                let settings = Image(systemName: "gear")
                Text("Use «\(qrButton) Scan QR codes» in the Actions menu to start a withdrawal if your bank already supports Taler payments.", comment: "« 􀎻 » 'qrcode.viewfinder'")
                    .talerFont(.body)
                    .listRowSeparator(.hidden)
                Text("You can also add a payment service manually in the \(settings) Settings tab.", comment: "« 􀍟 » 'gear'")
                    .talerFont(.body)
            }
            Section {
                Text("Demo: get digital cash to experience how to pay with the money of the future.")
                    .talerFont(.body)
                    .listRowSeparator(.hidden)
                let title = String(localized: "LinkTitle_Test_Money", defaultValue: "Get demo money")
                Button(title) {
                    withDrawDisabled = true    // don't run twice
                    Task { // runs on MainActor
                        let amount = Amount(currency:  DEMOCURRENCY, cent: 2500)
                        symLog.log("Withdraw KUDOS")
                        try? await model.loadTestKudosM(0, amount: amount)
                    }
                }
                .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, disabled: withDrawDisabled, aligned: .center))
                .disabled(withDrawDisabled)

//                Link(title, destination: URL(string: DEMOBANK)!)
//                    .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, aligned: .center))
//                    .padding(.vertical)
//                    .accessibilityHint(String(localized: "Will go to the demo bank website."))
            }
        }
        .listStyle(myListStyle.style).anyView
        .talerFont(.title2)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .overlay(loadingOverlay)
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_EMPTY_WALLET, stack: stack.push("onAppear"))     // 10
        }
    }
    @ViewBuilder private var loadingOverlay: some View {
        if withDrawDisabled {
            RotatingTaler(size: 150, progress: true, rotationEnabled: $withDrawDisabled)
        }
    }
}

struct WalletEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        WalletEmptyView(stack: CallStack("Preview"))
    }
}
