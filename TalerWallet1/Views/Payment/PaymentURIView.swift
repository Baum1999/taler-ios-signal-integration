/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct PaymentURIView: View {
    private let symLog = SymLogV()
    var url: URL
    @ObservedObject var model: PaymentURIModel
    @State var detailsForUri: PaymentDetailsForUri?

    let navTitle = String(localized: "Payment")

    var body: some View {
        let badURL = "Error in URL: \(url)"
        VStack {
            if model.paymentState == nil {
                LoadingView(backButtonHidden: false)
            } else { switch model.paymentState {
                case .waitingForUriDetails:
                    let _ = symLog.vlog("waitingForUriDetails")
                    WithdrawProgressView(message: url.host ?? badURL)
                        .navigationTitle("Contacting Exchange")
                case .receivedUriDetails:
                    let _ = symLog.vlog("waitingForUser")
                    PaymentAcceptView(model: model, detailsForAmount: detailsForUri!)
                default:
                    Text("Payment")
                        .navigationTitle(navTitle)
            } }
        }.task {
            do { // TODO: cancelled
                symLog.log(".task")
                detailsForUri = try await model.preparePayForUriM(url.absoluteString)
//                print(detailsForUri?.status)
//                print(detailsForUri?.amountRaw.description)
//                print(detailsForUri?.amountEffective.description)
//                print(detailsForUri?.proposalId)
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }
}
