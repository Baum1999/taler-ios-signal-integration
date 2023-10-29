/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct TwoRowButtons: View {
    let sendTitles: (String, String?)
    let recvTitles: (String, String?)
    let isHorizontal: Bool
    let lineLimit: Int
    let sendDisabled: Bool
    let sendAction: () -> Void
    let recvAction: () -> Void
    @Environment(\.sizeCategory) var sizeCategory
    
    func title(_ titles: (String, String?), _ horizontal: Bool) -> String {
        let delimiter = horizontal ? " " : "\n"
        let (title1, title2) = titles
        if let title2 {
            return title1 + delimiter + title2
        } else {
            return title1
        }
    }

    var body: some View {
        Group {
            Button(title(sendTitles, isHorizontal), action: sendAction)
                .lineLimit(lineLimit)
                .disabled(sendDisabled)
                .buttonStyle(TalerButtonStyle(type: .bordered,
                                            dimmed: false,
                                           aligned: .center))
            Button(title(recvTitles, isHorizontal), action: recvAction)
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
                            isHorizontal: true,
                               lineLimit: 2, sendDisabled: true,
                              sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
                TwoRowButtons(sendTitles: ("Send", DEMOCURRENCY),
                              recvTitles: ("Receive", DEMOCURRENCY),
                            isHorizontal: true,
                               lineLimit: 2, sendDisabled: true,
                              sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
        }
    }
}
