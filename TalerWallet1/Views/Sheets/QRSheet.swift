/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import CodeScanner
import SymLog
import AVFoundation

struct QRSheet: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var balances: [Balance]
    @Binding var selectedBalance: Balance?

    @State private var scannedCode: String?

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
        Group {
            if scannedCode != nil {
//                let _ = print(scannedCode as Any)       // TODO: logging

                if let scannedURL = codeToURL(scannedCode!) {
                    let scheme = scannedURL.scheme
                    if scheme?.lowercased() == "taler" {
                        URLSheet(stack: stack.push(),
                              balances: $balances,
                       selectedBalance: $selectedBalance,
                             urlToOpen: scannedURL)
                    } else {
//                        let _ = print(scannedURL)       // TODO: error logging
                        ErrorView(errortext: scannedURL.absoluteString)
                    }
                } else {
                    ErrorView(errortext: scannedCode)
                }
            } else {
                CodeScannerView(codeTypes: [AVMetadataObject.ObjectType.qr], showViewfinder: true) { response in
                    switch response {
                        case .success(let result):
                            symLog.log("Found code: \(result.string)")
                            scannedCode = result.string
                        case .failure(let error):
                            // TODO: errorAlert
                            ErrorView(errortext: error.localizedDescription)
                    }
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
