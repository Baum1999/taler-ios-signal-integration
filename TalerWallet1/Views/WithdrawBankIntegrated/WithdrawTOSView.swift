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

    let exchangeBaseUrl: String?

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
                    let acceptedFormat: [String] = [MARKDOWN, PLAINTEXT]
                    let someTOS = try await model.loadExchangeTermsOfServiceM(exchangeBaseUrl,
                                                                acceptedFormat: acceptedFormat)
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
                let components = tos.content.components(separatedBy: "\n\n")

                List (components, id: \.self) { term0 in
                    if tos.contentType == PLAINTEXT {
                        let term1 = term0.replacingOccurrences(of: "\n     ", with: " ")    // newline + 5 blanks
                        let term2 = term1.replacingOccurrences(of: "\n"     , with: " ")    // remove all other linebreaks
                        let term3 = term2.replacingOccurrences(of: " ====", with: "\n====") // add them back for underscoring
                        let term4 = term3.replacingOccurrences(of: " ----", with: "\n----") // special for "Highlights:"
                        let term5 = term4.replacingOccurrences(of: " ****", with: "\n****") // special for "Terms of Service:"
//                        Text("term0")
                        if #available(iOS 16.0, *) {
                            Section {
                                Text(term5)
                                    .accessibilityFont(.footnote)
                                    .foregroundColor(Color(UIColor.label))
                            }
                        } else {
                            Text(term5)
                                .accessibilityFont(.footnote)
                                .foregroundColor(Color(UIColor.label))
                        }
                    } else {        // MarkDown
                        Section {
                            Text(term0)
                                .accessibilityFont(.body)
                        }
                    }
                }.safeAreaInset(edge: .bottom) {
                    Button(String(localized: "Accept Terms of Service", comment: "Button"), action: acceptAction)
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
