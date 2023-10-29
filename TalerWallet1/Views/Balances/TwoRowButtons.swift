/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct TwoRowButtons: View {
    let sendTitles: (String, String)
    let recvTitles: (String, String)
    let horizontal:Bool
    let lineLimit: Int
    let sendDisabled: Bool
    let sendAction: () -> Void
    let recvAction: () -> Void
    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        let delimiter = horizontal ? " " : "\n"
        let (sendTitle1, sendTitle2) = sendTitles
        let (recvTitle1, recvTitle2) = recvTitles
        Group {
            Button(sendTitle1 + delimiter + sendTitle2, action: sendAction)
                .lineLimit(lineLimit)
                .disabled(sendDisabled)
                .buttonStyle(TalerButtonStyle(type: .bordered,
                                            dimmed: false,
                                           aligned: .center))
            Button(recvTitle1 + delimiter + recvTitle2, action: recvAction)
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
                TwoRowButtons(sendTitles: ("Send", TESTCURRENCY),
                              recvTitles: ("Receive", LONGCURRENCY),
                             horizontal: true,
                              lineLimit: 2, sendDisabled: true,
                             sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
                TwoRowButtons(sendTitles: ("Send", DEMOCURRENCY),
                              recvTitles: ("Receive", DEMOCURRENCY),
                             horizontal: true,
                              lineLimit: 2, sendDisabled: true,
                             sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
        }
    }
}
