/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import CodeScanner
import SymLog
import AVFoundation

struct QRSheet: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?

    @EnvironmentObject private var model: WalletModel
    @State private var scannedCode: String?
    @State private var urlToOpen: URL?

    func codeToURL(_ code: String) -> URL? {
        if let scannedURL = URL(string: code) {
            return scannedURL
        }
        if let encodedScan = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            if let encodedURL = URL(string: encodedScan) {
                return encodedURL
            }
        }
        return nil
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(scannedCode)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            let errorAnnouncement = String(localized: "Error while scanning QR code", comment: "VoiceOver")
            if scannedCode != nil {
                if let scannedURL = codeToURL(scannedCode!) {
                    let scheme = scannedURL.scheme
                    if scheme?.lowercased() == "taler" {
                        URLSheet(stack: stack.push(),
                       selectedBalance: $selectedBalance,
                             urlToOpen: $urlToOpen)
                    } else {
//                        let _ = print(scannedURL)       // TODO: error logging
                        ErrorSheet(title: String(localized: "Scanned QR is no talerURI"),
                                 message: scannedURL.absoluteString,
                                copyable: true) {
                            dismissTop(stack.push())
                        }
                    }
                } else {
                    ErrorSheet(title: String(localized: "Scanned QR is no URL"),
                             message: scannedCode,
                            copyable: true) {
                        dismissTop(stack.push())
                    }
                }
            } else {
                CodeScannerView(codeTypes: [AVMetadataObject.ObjectType.qr], showViewfinder: true) { response in
                    let closingAnnouncement: String
                    switch response {
                        case .success(let result):
                            symLog.log("Found code: \(result.string)")
                            scannedCode = result.string
                            urlToOpen = codeToURL(result.string)
                            closingAnnouncement = String(localized: "QR code recognized", comment: "VoiceOver")
                        case .failure(let error):
                            // TODO: errorAlert
                            model.setError(error)
                            closingAnnouncement = errorAnnouncement
                    }
                        announce(closingAnnouncement)
                }
            }
        }
    }

}
// MARK: -
//struct PaySheet_Previews: PreviewProvider {
//    static var previews: some View {
            // needs BackendManager
//        URLSheet(urlToOpen: URL(string: "ftp://this.URL.is.invalid")!)
//    }
//}
