/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct MailAddressInput: View {
    let stack: CallStack
    @Binding var text: String
//    @FocusState.Binding
    var isFocused: Bool
    let focusAction: () -> Void

    var body: some View {
        let label = String(localized: "Address:", comment: "TextEdit purpose, a11y")
        let placeHolder = EMPTYSTRING
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .talerFont(.title3)
            if #available(iOS 16.4, *) {
                TextField(placeHolder, text: $text, axis: .vertical)
                    .lineLimit(2...6)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .onChange(of: text) { newValue in
//                      .onSubmit {} doesn't work with multiple lines, so we need to check for "\n"
                        guard isFocused else { return }
                        guard newValue.contains(LINEFEED) else { return }
                        focusAction()
                        text = newValue.replacing(LINEFEED, with: EMPTYSTRING)
                    }
                    .talerFont(.title3)
//                  .accessibilityLabel(label)
            } else {
                TextField(placeHolder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
//                    .focused($isFocused)
                    .onSubmit {
                        guard isFocused else { return }
                        focusAction()
                    }
                    .talerFont(.title2)
            }
        }
    }
}
