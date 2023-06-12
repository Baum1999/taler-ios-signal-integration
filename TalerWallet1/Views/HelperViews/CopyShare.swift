/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import UniformTypeIdentifiers
import SwiftUI
import SymLog

struct CopyButton: View {
    private let symLog = SymLogV(0)
    @Environment(\.isEnabled) private var isEnabled: Bool
    let textToCopy: String
    let vertical: Bool

    func copyAction() -> Void {
        symLog.log(textToCopy)
        UIPasteboard.general.setValue(textToCopy,
                                      forPasteboardType: UTType.plainText.identifier)
    }

    var body: some View {
        Button(action: copyAction) {
            if vertical {
                VStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy", comment: "5 letters max, else abbreviate")
                }
            } else {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy", comment: "may be a bit longer")
                }
            }
        }
        .disabled(!isEnabled)
    }
}
// MARK: -
struct ShareButton: View {
    private let symLog = SymLogV(0)
    @Environment(\.isEnabled) private var isEnabled: Bool

    let textToShare: String
    let dismissFirst: Bool

    func shareAction() -> Void {
        if dismissFirst {
            dismissTop()        // cannot open another sheet from within a sheet
        }
        symLog.log(textToShare)
        ShareSheet.shareSheet(url: textToShare)
    }

    var body: some View {
        Button(action: shareAction) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share")
            }
        }
        .disabled(!isEnabled)
    }
}
// MARK: -
struct CopyShare: View {
    @Environment(\.isEnabled) private var isEnabled: Bool

    let textToCopy: String
    let dismissFirst: Bool

    var body: some View {
        HStack {
            CopyButton(textToCopy: textToCopy, vertical: false)
                .buttonStyle(TalerButtonStyle(type: .bordered))
            ShareButton(textToShare: textToCopy, dismissFirst: dismissFirst)
                .buttonStyle(TalerButtonStyle(type: .bordered))
        } // two buttons
    }
}
// MARK: -
struct CopyShare_Previews: PreviewProvider {
    static var previews: some View {
        CopyShare(textToCopy: "Hallö", dismissFirst: false)
    }
}
