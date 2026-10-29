/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct StandardInput: View {
    let stack: CallStack
    let label: String
    let placeHolder: String
    @Binding var text: String
//    let submitAction: () -> Void

    var body: some View {
        let textField = TextField(placeHolder, text: $text)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
        if #available(iOS 16.4, *) {
            LabeledContent(label) {
                textField
            }
            .talerFont(.title3)
//            .accessibilityLabel(label)
        } else {
            Text(label)
                .talerFont(.title3)
            textField
                .talerFont(.title2)
        }
    }
}
// MARK: -
struct AliasInput: View {
    let stack: CallStack
    @Binding var text: String
    let lastAlias: String
    let changeAction: () -> Void

    var body: some View {
        let label = String(localized: "Alias:", comment: "TextEdit purpose, a11y")
        let placeHolder = "user@example.com"
        let textField = TextField(placeHolder, text: $text)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
//          .frame(height: frameHeight)
            .onChange(of: text) { newVal in
                if newVal != lastAlias {
                    changeAction()            // lookupState = .unknown
                }
            }
//          .submitLabel(.search)           just stick with the standard 􀅇

        if #available(iOS 16.4, *) {
            LabeledContent(label) {
                textField
            }
            .talerFont(.title3)
//          .accessibilityLabel(label)
        } else {
            Text(label)
                .talerFont(.title3)
            textField
                .talerFont(.title2)
        }
    }
}
