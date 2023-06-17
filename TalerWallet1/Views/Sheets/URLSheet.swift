/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct URLSheet: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Invalid URL")
    var urlToOpen: URL
    @EnvironmentObject private var controller: Controller

    @State private var urlCommand: UrlCommand? = nil

    var body: some View {
        Group {
            if urlCommand == .withdraw {
                WithdrawURIView(url: urlToOpen)
            } else if urlCommand == UrlCommand.pay {
                let model = PaymentURIModel.model()
                PaymentURIView(url: urlToOpen, model: model)
            } else {
                VStack {        // Error view
                    Spacer()
                    Text(controller.messageForSheet ?? urlToOpen.absoluteString)
                        .font(.title)
                    Spacer()
                    Spacer()
                }
                .navigationTitle(navTitle)
            }
        }.task {
            urlCommand = controller.openURL(urlToOpen)
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
