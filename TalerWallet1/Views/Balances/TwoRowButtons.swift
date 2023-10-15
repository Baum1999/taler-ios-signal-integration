/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct TwoRowButtons: View {
    let sendTitle: String
    let recvTitle: String
    let lineLimit: Int
    let sendDisabled: Bool
    let sendAction: () -> Void
    let recvAction: () -> Void
    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        Group {
            Button(sendTitle, action: sendAction)
                .lineLimit(lineLimit)
                .disabled(sendDisabled)
                .buttonStyle(TalerButtonStyle(type: .bordered,
                                            dimmed: false,
                                           aligned: .center))
            Button(recvTitle, action: recvAction)
                .lineLimit(lineLimit)
                .disabled(false)
                .buttonStyle(TalerButtonStyle(type: .bordered,
                                            dimmed: false,
                                           aligned: .center))
        }
    }
}

struct TwoRowButtons_Previews: PreviewProvider {
    static var previews: some View {
        List {
                TwoRowButtons(sendTitle: "Send\n" + TESTCURRENCY,
                              recvTitle: "Receive\n" + LONGCURRENCY,
                              lineLimit: 2, sendDisabled: true,
                             sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
                TwoRowButtons(sendTitle: "Send\n" + DEMOCURRENCY,
                              recvTitle: "Receive\n" + DEMOCURRENCY,
                              lineLimit: 2, sendDisabled: true,
                             sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
        }
    }
}
