/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct URLSheet: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Checking Link")
    var urlToOpen: URL
    @EnvironmentObject private var controller: Controller

    var body: some View {
        let urlCommand = controller.openURL(urlToOpen)

        Group {
            switch urlCommand {
                case .withdraw:
                    WithdrawURIView(url: urlToOpen)
                case .pay:
                    PaymentURIView(url: urlToOpen)
                case .payPull:
                    P2pPayURIView(url: urlToOpen)
                case .payPush:
                    P2pReceiveURIView(url: urlToOpen)
                case .unknown:        // Error view
                    VStack {
                        Text("unknown command")
                            .font(.title)
                        Text(controller.messageForSheet ?? urlToOpen.absoluteString)
                    }
                    .navigationTitle(navTitle)
            }
        }
    }
}
// MARK: -
//struct PaySheet_Previews: PreviewProvider {
//    static var previews: some View {
            // needs BackendManager
//        URLSheet(urlToOpen: URL(string: "ftp://this.URL.is.invalid")!)
//    }
//}
