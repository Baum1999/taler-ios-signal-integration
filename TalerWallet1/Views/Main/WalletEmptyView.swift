/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @State private var withDrawStarted = false

    var body: some View {
        let list = List {
            Section {
                Text("Welcome to Taler Wallet!", comment: "")
                    .talerFont(.body)
#if TALER_WALLET
                let qrButton = Image(systemName: QRBUTTON)                      // 􀎻 "qrcode.viewfinder"
                let settings = Image(systemName: SETTINGS)                      // 􀍟 "gear"
                Text("Use «\(qrButton) Scan QR code» in the Actions menu to start a withdrawal if your bank already supports Taler payments.", comment: "« 􀎻 » 'qrcode.viewfinder'")
                    .talerFont(.body)
                Text("You can also add a payment service manually in the \(settings) Settings tab.", comment: "« 􀍟 » 'gear'")
                    .talerFont(.body)
#else//if TALER_NIGHTLY
                Text("To make your first payment please withdraw some digital cash.", comment: "")
                    .talerFont(.body)

                let title = String(localized: "LinkTitle_Withdraw", defaultValue: "Withdraw CHF")
                Button(title) {
                        // TODO: go to withdraw view
                }
                    .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, disabled: withDrawStarted, aligned: .center))
                    .padding(.bottom)
#endif
#if DEBUG
              if developerMode {
                Text("Either deposit or send your money to a friend before you delete the app, or it will be lost.", comment: "")
                    .talerFont(.body)
              }
#endif
            } header: {
                let firstHeader = EMPTYSTRING
                Text(firstHeader)
                    .talerFont(.badge)
                /// YIKES! when not specifying this color, the Text in the BarGraphHeader vanishes!!!
                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                    .listRowInsets(EdgeInsets())  // << here !!
            }
            .listRowSeparator(.hidden)
            Section {
                Text("Get digital cash to experience how to pay with the money of the future.")
                    .talerFont(.body)
                    .listRowSeparator(.hidden)
                let title = String(localized: "LinkTitle_Test_Money", defaultValue: "Get demo cash")
                Button(title) {
                    withDrawStarted = true    // don't run twice
                    Task { // runs on MainActor
                        let amount = Amount(currency:  DEMOCURRENCY, cent: 2500)
                        symLog.log("Withdraw KUDOS")
                        try? await model.loadTestKudos(0, amount: amount)
                    }
                }
                .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, disabled: withDrawStarted, aligned: .center))
                .disabled(withDrawStarted)
//            } header: {
//                let secondHeader = String(localized: "Demo", comment: "section header")
//                Text(secondHeader)
//                    .talerFont(.title3)
//                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
            }
        }
            .listStyle(myListStyle.style).anyView
            .talerFont(.title2)
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        ZStack {
            list
            if withDrawStarted {
                RotatingTaler(size: 150, progress: true, rotationEnabled: $withDrawStarted)
            }
        }
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
