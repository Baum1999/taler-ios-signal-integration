/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct WithdrawTOSView: View {
    private let symLog = SymLogV()
    @AppStorage("listStyle") var myListStyle = MyListStyle.automatic

    let navTitle = String(localized: "Terms of Service")

    var exchangeBaseUrl: String
    @ObservedObject var model: WithdrawModel

    @State var exchangeTOS: ExchangeTermsOfService?
    let viewID: Int         // either VIEW_WITHDRAW_TOS or SHEET_WITHDRAW_TOS

    let acceptAction: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            switch model.withdrawState {
                case .receivedAmountDetails, .waitingForTOS:
                    WithdrawProgressView(message: exchangeBaseUrl.trimURL())
                        .navigationTitle("Loading " + navTitle)
                case .receivedTOS, .waitingForTOSAck, .receivedTOSAck:
                    Content(symLog: symLog, exchangeTOS: exchangeTOS, myListStyle: $myListStyle) {
                        Task {
                            do {
                                _ = try await model.setExchangeTOSAcceptedM(exchangeBaseUrl, etag: exchangeTOS!.currentEtag)
                                if acceptAction != nil {
                                    acceptAction!()
                                } else {
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                            } catch {    // TODO: Show Error
                                symLog.log(error.localizedDescription)
                            }
                        }
                    }
                        .navigationBarTitleDisplayMode(.large)      // .inline
                        .navigationTitle(navTitle)
                default:
                    ErrorView(errortext: "unknown state")   // TODO: ???
            }
        }.onAppear() {
            if viewID > SHEET_WITHDRAWAL {
                DebugViewC.shared.setSheetID(SHEET_WITHDRAW_TOS)
            } else {
                DebugViewC.shared.setViewID(VIEW_WITHDRAW_TOS)
            }
        }.task {
            do {
                let someTOS = try await model.loadExchangeTermsOfServiceM(exchangeBaseUrl)
                exchangeTOS = someTOS
            } catch {    // TODO: error
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
        @Binding var myListStyle: MyListStyle
        var acceptAction: () -> ()

        var body: some View {
            if let tos = exchangeTOS {
                let components = tos.content.components(separatedBy:"\n\n")

                List (components, id: \.self) { term in
                    Text(term)
                }.safeAreaInset(edge: .bottom) {
                    ProminentButton(title: String(localized: "Accept"), action: acceptAction)
                        .padding(.horizontal)
                }
                .listStyle(myListStyle.style)
                .anyView
            } else {
                ErrorView(errortext: String(localized: "unknown ToS"))     // TODO: ???
            }
        }
    }
}
