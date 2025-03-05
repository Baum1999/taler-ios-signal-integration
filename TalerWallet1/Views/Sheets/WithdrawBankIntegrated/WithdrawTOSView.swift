/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import MarkdownUI

struct WithdrawTOSView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let exchangeBaseUrl: String?
    let viewID: Int         // either VIEW_WITHDRAW_TOS or SHEET_WITHDRAW_TOS
    let acceptAction: (() async -> Void)?

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State var exchangeTOS: ExchangeTermsOfService?

    let navTitle = String(localized: "Terms of Service")

    @MainActor
    func loadToS(_ language: String) async {
        if let exchangeBaseUrl {
            let acceptedFormat: [String] = [MARKDOWN, PLAINTEXT]      // MARKDOWN, HTML, PLAINTEXT
            if let someTOS = try? await model.loadExchangeTermsOfService(exchangeBaseUrl,
                                                         acceptedFormat: acceptedFormat,
                                                         acceptLanguage: language) {
                exchangeTOS = someTOS
            }
        } else {
            // TODO: Yikes! No baseURL
        }
    }

    @MainActor
    func viewDidLoad() async {
        if let exchangeTOS, let exchangeBaseUrl {
            _ = try? await model.setExchangeTOSAccepted(exchangeBaseUrl)
            if acceptAction != nil {
                await acceptAction!()
            } else { // just go back - caller will reload
                self.presentationMode.wrappedValue.dismiss()
            }
        } else {
            // TODO: error
        }
    }

    var body: some View {
        let languageCode = Locale.preferredLanguageCode
//        let languageName = Locale.current.localizedString(forLanguageCode: languageCode)
        if let exchangeTOS {
            Content(symLog: symLog, tos: exchangeTOS, myListStyle: $myListStyle,
                  language: languageCode, languageAction: loadToS) {
                Task { await viewDidLoad() }
            }
            .navigationTitle(navTitle)
            .onAppear() {
                if viewID > SHEET_WITHDRAWAL {
                    DebugViewC.shared.setSheetID(SHEET_WITHDRAW_TOS)
                } else {
                    DebugViewC.shared.setViewID(VIEW_WITHDRAW_TOS, stack: stack.push())
                }
            }
        } else {
            let fallback = String(localized: "No payment service", comment: "loading")
            LoadingView(stack: stack.push(), scopeInfo: nil,
                        message: exchangeBaseUrl?.trimURL ?? fallback)
                .task {
                    await loadToS(languageCode)
                }
        }
    }
}
// MARK: -
extension WithdrawTOSView {

    static func cleanupText(_ term0: String) -> String {
        let term1 = term0.replacingOccurrences(of: "\n     ", with: " ")    // newline + 5 blanks
        let term2 = term1.replacingOccurrences(of: "\n    ", with: " ")     // newline + 4 blanks
        let term3 = term2.replacingOccurrences(of: "\n   ", with: " ")      // newline + 3 blanks
        let term4 = term3.replacingOccurrences(of: "\n  ", with: " ")       // newline + 2 blanks
        let term5 = term4.replacingOccurrences(of: "\n ", with: " ")        // newline + 1 blank
        let term6 = term5.replacingOccurrences(of: "\n", with: " ")         // remove all other linebreaks
        let term7 = term6.replacingOccurrences(of: " ====", with: "\n====") // add them back for underscoring
        let term8 = term7.replacingOccurrences(of: " ----", with: "\n----") // special for "Highlights:"
        let term9 = term8.replacingOccurrences(of: " ****", with: "\n****") // special for "Terms of Service:"
        return term9
    }

    struct plaintextToSV: View {
        let plaintext: String

        var body: some View {
            let components = plaintext.components(separatedBy: "\n\n")
            ForEach (components, id: \.self) { term0 in
                Section {
                    Text(cleanupText(term0))
                        .talerFont(.footnote)
                        .foregroundColor(Color(UIColor.label))
                }
            } // for
        }
    }

    struct Content: View {
        let symLog: SymLogV
        var tos: ExchangeTermsOfService
        @Binding var myListStyle: MyListStyle
        let language: String
        var languageAction: (String) async -> ()
        var acceptAction: () -> ()

        @State private var selectedLanguage = Locale.preferredLanguageCode

        var body: some View {
            let title = String(localized: "Language:", comment: "title of ToS language selection")
            let list = List {
              if tos.tosAvailableLanguages.count > 1 {
                Picker(title, selection: $selectedLanguage) {
                        ForEach(tos.tosAvailableLanguages, id: \.self) { code in
                            let languageName = Locale.current.localizedString(forLanguageCode: code)
                            Text(languageName ?? code)
                    }
                }
                .talerFont(.title3)
                .pickerStyle(.menu)
                .onAppear() {
                    withAnimation { selectedLanguage = language }
                }
                .onChange(of: selectedLanguage) { selected in
                    Task {
                        await languageAction(selected)
                    }
                }
              }
                if tos.contentType == MARKDOWN {
                    Section {
                        let content = MarkdownContent(tos.content)
                        Markdown(content)
                    }
                } else {
                    let components = tos.content.components(separatedBy: "\n\n")
                    ForEach (components, id: \.self) { term0 in
                        Section {
                            Text(cleanupText(term0))
                                .talerFont(.footnote)
                                .foregroundColor(Color(UIColor.label))
                        }
                    } // for
                } // plain text
            }.listStyle(myListStyle.style).anyView

            let currentEtag = tos.currentEtag
            let showButton = tos.acceptedEtag == nil ? true
                           : tos.acceptedEtag! == tos.currentEtag ? false
                                                                  : true
            let button = Button(String(localized: "Accept Terms of Service", comment: "Button"), action: acceptAction)
                            .buttonStyle(TalerButtonStyle(type: .prominent))
                            .padding(.horizontal)
            list.safeAreaInset(edge: .bottom) {
                if showButton {
                    button
//                        .padding(.bottom, 40)
                }
            }
        }
    }
}
