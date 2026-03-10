/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct ToSButtonView: View {
    let stack: CallStack
    let exchangeBaseUrl: String?
    let viewID: Int         // either VIEW_WITHDRAW_TOS or SHEET_WITHDRAW_TOS
    let p2p: Bool
    let acceptAction: (() async -> Void)?

    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        let hint = minimalistic ? String(localized: "You must first accept the payment service's terms of service.")
                          : p2p ? String(localized: "You must first accept the payment service's terms of service before you can receive digital cash in your wallet.", comment: "P2P Receive")
                                : String(localized: "You must first accept the payment service's terms of service before you can withdraw digital cash to your wallet.")
        Text(hint)
            .talerFont(.body)
            .multilineTextAlignment(.leading)
            .padding()
        let destination = WithdrawTOSView(stack: stack.push(),
                                exchangeBaseUrl: exchangeBaseUrl,
                                         viewID: viewID,
                                   acceptAction: acceptAction)                  // pop back to here
        NavigationLink(destination: destination) {
            Text("Terms of Service")  // VIEW_WITHDRAW_TOS
        }.buttonStyle(TalerButtonStyle(type: .prominent))
            .padding(.horizontal)
#if false
        let title = "getPerformanceStats"
        Button(title) {
            Task {
                try? await model.getPerformanceStats()
            }
        }
#endif
    }
}

#Preview {
    ToSButtonView(stack: CallStack("Preview"), exchangeBaseUrl: nil, viewID: 0, p2p: false, acceptAction: nil)
}
