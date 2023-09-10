/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

struct WithdrawProgressView: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
            HStack {
                Spacer()
                Text(message)
                    .accessibilityFont(.title)
                Spacer()
            }
            Spacer()
            Spacer()
        }
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
    }
}

struct WithdrawProgressView_Previews: PreviewProvider {
    static var previews: some View {
        WithdrawProgressView(message: "message")
    }
}
