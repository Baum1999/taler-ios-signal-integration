/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
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

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                let width = UIScreen.screenWidth / 3
                let height = 4.0
                Rectangle()
                    .opacity(0.001)
                    .frame(width: width, height: height)
                RoundedRectangle(cornerRadius: 2)
                    .foregroundColor(.primary)
                    .frame(width: width, height: height)
                Rectangle()
                    .opacity(0.001)
                    .frame(width: width, height: height)
            } // drop bar
            .listRowSeparator(.hidden)

            if hasKudos {
                if !minimalistic && showSpendingHint {
                    Text("You can spend your \(DEMOCURRENCY) in the Demo shop, or send them to another wallet.")
                        .talerFont(.body)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)           // must set this otherwise fixedInnerHeight doesn't work
                        .listRowSeparator(.hidden)
                }
                let title = String(localized: "LinkTitle_DEMOSHOP", defaultValue: "Spend demo money")
                let action = {
                    showSpendingHint = false
                    UIApplication.shared.open(URL(string:DEMOSHOP)!, options: [:])
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
                .listRowSeparator(.hidden)
                .padding(.bottom, 20)
            }

            SendRequestV(stack: stack.push(),
                      balances: $balances,
              amountToTransfer: $amountToTransfer,   // does still have the wrong currency
                       summary: $summary,
                  cameraAction: cameraAction)

            DepositWithdrawV(stack: stack.push(),
                          balances: $balances,
                  amountToTransfer: $amountToTransfer)   // does still have the wrong currency
            .padding(.bottom, 12)
        }
        .task {
            print("ActionsSheet.task❓HideTabBarView")
            NotificationCenter.default.post(name: .HideTabBarView, object: nil)
        }
    }
}
// MARK: -
//#Preview {
//    @Previewable @State var balances: [Balance] = []
//    Actions(stack: CallStack("Preview"), balances: $balances, ...)
//}
