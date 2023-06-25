/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct WithdrawTOSView: View {
    private let symLog = SymLogV()
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let navTitle = String(localized: "Terms of Service")

    var exchangeBaseUrl: String?

    @EnvironmentObject private var model: WalletModel

    @State var exchangeTOS: ExchangeTermsOfService?
    let viewID: Int         // either VIEW_WITHDRAW_TOS or SHEET_WITHDRAW_TOS

    let acceptAction: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Content(symLog: symLog, exchangeTOS: exchangeTOS, myListStyle: $myListStyle) {
                Task {
                    do {
                        if let exchangeBaseUrl {
                            _ = try await model.setExchangeTOSAcceptedM(exchangeBaseUrl, etag: exchangeTOS!.currentEtag)
                            if acceptAction != nil {
                                acceptAction!()
                            } else { // just go back - caller will reload
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        }
                    } catch {    // TODO: Show Error
                        symLog.log(error.localizedDescription)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.large)      // .inline
            .navigationTitle(navTitle)
            .overlay {
                if exchangeTOS == nil {
                    if let exchangeBaseUrl {
                        WithdrawProgressView(message: exchangeBaseUrl.trimURL())
                            .navigationTitle("Loading " + navTitle)
                    } else {
                        // Yikes!
                        WithdrawProgressView(message: "No exchangeBaseUrl!")
                            .navigationTitle("Loading " + navTitle)
                    }
                }
            }
        }.onAppear() {
            if viewID > SHEET_WITHDRAWAL {
                DebugViewC.shared.setSheetID(SHEET_WITHDRAW_TOS)
            } else {
                DebugViewC.shared.setViewID(VIEW_WITHDRAW_TOS)
            }
        }.task {
            do {
                if let exchangeBaseUrl {
                    let someTOS = try await model.loadExchangeTermsOfServiceM(exchangeBaseUrl)
                    exchangeTOS = someTOS
                }
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
                    Button(String(localized: "Accept ToS"), action: acceptAction)
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                }
                .listStyle(myListStyle.style).anyView
            } else {
                ErrorView(errortext: String(localized: "unknown ToS"))     // TODO: ???
            }
        }
    }
}
