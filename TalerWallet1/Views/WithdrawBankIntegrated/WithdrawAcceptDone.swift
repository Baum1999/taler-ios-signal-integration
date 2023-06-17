/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct WithdrawAcceptDone: View {
    private let symLog = SymLogV()
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let confirmTransferUrl: String?

    let navTitle = String(localized: "Confirm with Bank")

    var body: some View {
        VStack {
            Text(navTitle)
                .font(.title)
                .padding()
            List {
                if let confirmTransferUrl {
                    let destination = URL(string: confirmTransferUrl)!
                    // Show Hint that User should Confirm on bank website
                    Text("Waiting for bank confirmation")
                        .listRowSeparator(.hidden)
                    
                    
                    Link("Confirm with bank", destination: destination)
                        .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, aligned: .center))
                    // balances will be updated by TransactionStateTransition
                }
            }
            .listStyle(myListStyle.style).anyView

        }
        .interactiveDismissDisabled()       // can only use "Done" button to dismiss
        .navigationBarHidden(true)          // no back button, no title
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))

        .safeAreaInset(edge: .bottom) {
            Button("Done", action: { dismissTop() })
                .lineLimit(2)
                .disabled(false)
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                .padding()
        }
        .navigationTitle(navTitle)
        .onAppear() {
            DebugViewC.shared.setSheetID(SHEET_WITHDRAW_CONFIRM)
        }
    }
}
// MARK: -
struct WithdrawAcceptDone_Previews: PreviewProvider {
    static var previews: some View {
        WithdrawAcceptDone(confirmTransferUrl: DEMOBANK)
    }
}
