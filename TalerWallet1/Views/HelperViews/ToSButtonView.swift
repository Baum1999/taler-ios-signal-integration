//
//  ToSButtonView.swift
//  TalerWallet
//
//  Created by Marc Stibane on 2023-09-05.
//  Copyright © 2023 Taler. All rights reserved.
//

import SwiftUI

struct ToSButtonView: View {
    let stack: CallStack
    let exchangeBaseUrl: String?
    let viewID: Int         // either VIEW_WITHDRAW_TOS or SHEET_WITHDRAW_TOS
    let p2p: Bool

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        let hint = minimalistic ? String(localized: "You must accept the Payment Service's Terms of Service first.")
                          : p2p ? String(localized: "You must accept the Payment Service Provider's Terms of Service first before you can receive electronic cash in your wallet.", comment: "P2P Receive")
                                : String(localized: "You must accept the Payment Service Provider's Terms of Service first before you can use it to withdraw electronic cash to your wallet.")
        Text(hint)
            .talerFont(.body)
            .multilineTextAlignment(.leading)
            .padding()
        NavigationLink(destination: LazyView {
            WithdrawTOSView(stack: stack.push(),
                  exchangeBaseUrl: exchangeBaseUrl,
                           viewID: viewID,
                     acceptAction: nil)         // pop back to here
        }) {
            Text("Terms of Service")  // VIEW_WITHDRAW_TOS
        }.buttonStyle(TalerButtonStyle(type: .prominent))
            .padding(.horizontal)
    }
}

#Preview {
    ToSButtonView(stack: CallStack("Preview"), exchangeBaseUrl: nil, viewID: 0, p2p: false)
}
