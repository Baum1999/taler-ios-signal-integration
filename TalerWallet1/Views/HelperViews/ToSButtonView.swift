//
//  ToSButtonView.swift
//  TalerWallet
//
//  Created by Marc Stibane on 2023-09-05.
//  Copyright © 2023 Taler. All rights reserved.
//

import SwiftUI

struct ToSButtonView: View {
    let exchangeBaseUrl: String?
    let viewID: Int         // either VIEW_WITHDRAW_TOS or SHEET_WITHDRAW_TOS
    let p2p: Bool

    var body: some View {
        let hint = p2p ? String(localized: "You must accept the Exchange's Terms of Service first before you can receive electronic cash in your wallet.", comment: "P2P Receive")
                       : String(localized: "You must accept the Exchange's Terms of Service first before you can use it to withdraw electronic cash to your wallet.")
        Text(hint)
            .accessibilityFont(.body)
            .multilineTextAlignment(.leading)
            .padding()
        NavigationLink(destination: LazyView {
            WithdrawTOSView(exchangeBaseUrl: exchangeBaseUrl,
                                     viewID: viewID,
                               acceptAction: nil)         // pop back to here
        }) {
            Text("Terms of Service")  // VIEW_WITHDRAW_TOS
        }.buttonStyle(TalerButtonStyle(type: .prominent))
    }
}

#Preview {
    ToSButtonView(exchangeBaseUrl: nil, viewID: 0, p2p: false)
}
