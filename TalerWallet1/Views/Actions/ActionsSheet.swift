/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import os.log
import taler_swift

/// This view shows the action sheet
/// optional:   [􀰟Spend KUDOS]
///    [􁉇Send]  [􁉅Request]
/// [􁾭Withdraw]  [􁾩Deposit]
struct ActionsSheet: View {
    let stack: CallStack
    @Binding var balances: [Balance]
    @Binding var showSpendingHint: Bool
    @Binding var amountToTransfer: Amount       // does still have the wrong currency
    @Binding var summary: String
    let cameraAction: () -> Void

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("hideSpendingHint") var hideSpendingHint: Bool = false

    private var hasKudos: Bool {
        for balance in balances {
            if balance.scopeInfo.currency == DEMOCURRENCY {
                if !balance.available.isZero {
                    return true
                }
            }
        }
        return false
    }

    @MainActor
    func qrButtonTapped() {
        dismissTop(stack.push())
        NotificationCenter.default.post(name: .QrScanAction,
                                        object: nil)                              // will trigger NavigationLink
    }

    var body: some View {
        VStack {
            let width = UIScreen.screenWidth / 3
            RoundedRectangle(cornerRadius: 8)                                   // dropBar
                .foregroundColor(.primary)
                .frame(width: width + 6.5, height: 5)
                .padding(.bottom, 10)

            if hasKudos && !hideSpendingHint {
                if !minimalistic && showSpendingHint {
                    Text("You can spend your \(DEMOCURRENCY) in the Demo shop, or send them to another wallet.")
                        .talerFont(.body)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)           // must set this otherwise fixedInnerHeight doesn't work
                }
                let title = String(localized: "LinkTitle_DEMOSHOP", defaultValue: "Spend demo money")
                let action = {
                    hideSpendingHint = true
                    UIApplication.shared.open(URL(string:DEMOSHOP)!, options: [:])
                    dismissTop(stack.push())
                }
                Button(action: action) {
                    HStack {
                        ButtonIconBadge(type: .payment, foreColor: .accentColor, done: false)
                        Spacer()
                        Text(title)
                        Spacer()
                    }
                }
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                .accessibilityHint(String(localized: "Will go to the demo shop website."))
                .padding(.bottom, 20)
            }

            QRButton(isNavBarItem: false, action: qrButtonTapped)
                .lineLimit(5)
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .center))

            SendRequestV(stack: stack.push(),
                      balances: $balances,
              amountToTransfer: $amountToTransfer,   // does still have the wrong currency
                       summary: $summary)

            DepositWithdrawV(stack: stack.push(),
                          balances: $balances,
                  amountToTransfer: $amountToTransfer)   // does still have the wrong currency
        }
    }
}
// MARK: -
//#Preview {
//    @Previewable @State var balances: [Balance] = []
//    Actions(stack: CallStack("Preview"), balances: $balances, ...)
//}
