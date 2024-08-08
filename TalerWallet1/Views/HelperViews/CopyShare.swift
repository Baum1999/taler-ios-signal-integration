/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import UniformTypeIdentifiers
import SwiftUI
import SymLog

struct CopyButton: View {
    private let symLog = SymLogV(0)
    let textToCopy: String
    let vertical: Bool

    @Environment(\.isEnabled) private var isEnabled: Bool
    @EnvironmentObject private var controller: Controller

    func copyAction() -> Void {
        symLog.log(textToCopy)
        controller.hapticFeedback(.medium)
        UIPasteboard.general.setValue(textToCopy,
                                      forPasteboardType: UTType.plainText.identifier)
    }

    var body: some View {
        Button(action: copyAction) {
            if vertical {
                VStack {
                    let shortCopy = String(localized: "Copy.short", defaultValue: "Copy", comment: "5 letters max, else abbreviate")
                    Image(systemName: "doc.on.doc")
                        .accessibility(hidden: true)
                    Text(shortCopy)
                }
            } else {
                let longCopy = String(localized: "Copy.long", defaultValue: "Copy", comment: "may be a bit longer")
                HStack {
                    Image(systemName: "doc.on.doc")
                        .accessibility(hidden: true)
                    Text(longCopy)
                }
            }
        }
        .talerFont(.body)
        .disabled(!isEnabled)
    }
}
// MARK: -
@MainActor
struct ShareButton: View {
    private let symLog = SymLogV(0)
    let textToShare: String
    let title: String

    init(textToShare: String) {
        self.textToShare = textToShare
        self.title = String(localized: "Share")
    }
    init(textToShare: String, title: String) {
        self.textToShare = textToShare
        self.title = title
    }

    @Environment(\.isEnabled) private var isEnabled: Bool
    @EnvironmentObject private var controller: Controller

    func shareAction() -> Void {
        symLog.log(textToShare)
        controller.hapticFeedback(.soft)
        ShareSheet.shareSheet(url: textToShare)
    }

    var body: some View {
        Button(action: shareAction) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .accessibility(hidden: true)
                Text(title)
            }
        }
        .talerFont(.body)
        .disabled(!isEnabled)
    }
}
// MARK: -
struct CopyShare: View {
    @Environment(\.isEnabled) private var isEnabled: Bool

    let textToCopy: String

    var body: some View {
        HStack {
            CopyButton(textToCopy: textToCopy, vertical: false)
                .buttonStyle(TalerButtonStyle(type: .bordered))
            ShareButton(textToShare: textToCopy)
                .buttonStyle(TalerButtonStyle(type: .bordered))
        } // two buttons
    }
}
// MARK: -
struct CopyShare_Previews: PreviewProvider {
    static var previews: some View {
        CopyShare(textToCopy: "Hallö")
    }
}
