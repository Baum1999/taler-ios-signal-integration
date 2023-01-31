/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
import SwiftUI
import SymLog

struct WithdrawTOSView: View {
    private let symLog = SymLogV()
    var url: URL
    @ObservedObject var model: WithdrawURIModel

//    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    let navTitle = "Terms of Service"
    var cancelButton: some View {
        Button("Cancel3") { dismissTop() }
    }

    var detailsForUri: WithdrawalDetailsForUri
    @State var exchangeTOS: ExchangeTermsOfService?
    @Binding var didAcceptTOS: Bool

    var body: some View {
        let badURL = "Error in URL: \(url)"
        let baseURL = detailsForUri.defaultExchangeBaseUrl
        VStack {
            switch model.withdrawState {
                case .waitingForTOS:
                    WithdrawProgressView(message: baseURL ?? badURL) {
                        dismissTop()
                    }.navigationTitle("Loading " + navTitle)
                case .receivedTOS:
                    Content(symLog: symLog, exchangeTOS: exchangeTOS) {
                        Task {
                            do {
                                _ = try await model.setExchangeTOSAccepted(baseURL!, etag: exchangeTOS!.currentEtag)
                                didAcceptTOS = true
                            } catch {
                                // TODO: Show Error
                                symLog.log(error.localizedDescription)
                            }
                        }
                    }
                        .navigationBarTitleDisplayMode(.large)      // .inline
                        .navigationBarItems(leading: cancelButton)
                        .navigationTitle(navTitle)
                default:
                    ErrorView()
            }
        }.task {
            do {
                let someTOS = try await model.loadExchangeTermsOfService(baseURL!)
                exchangeTOS = someTOS
            } catch {
                // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }
}
// MARK: -
extension WithdrawTOSView {
    struct Content: View {
        let symLog: SymLogV
        var exchangeTOS: ExchangeTermsOfService?
        var acceptAction: () -> ()

        var body: some View {
            Group {
                if let tos = exchangeTOS {
                    let components = tos.content.components(separatedBy:"\n\n")

                    List (components, id: \.self) { term in
                        Text(term)
                    }
                    AwesomeButton(title: "Accept") {
                        acceptAction()
                    }.padding(.vertical)
                } else {
                    ErrorView()     // TODO: ???
                }
            }
        }
    }
}
