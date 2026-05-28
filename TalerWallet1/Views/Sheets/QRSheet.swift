/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
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
    let selectedBalance: Balance?
    @Binding var scannedSomething: Bool

    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var scannedCode: String?
    @State private var isTorchOn: Bool = false

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(scannedCode)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            let errorAnnouncement = String(localized: "Error while scanning QR code", comment: "a11y")
            if scannedCode != nil {
                if let scannedURL = scannedCode!.toURL {
                    let scheme = scannedURL.scheme
                    if scheme?.lowercased() == "taler" {
                        URLSheet(stack.push(),
                       selectedBalance: selectedBalance,
                              sheetURL: scannedURL)
                    } else {
                        // TODO: error logging?
                        ErrorView(stack.push(),
                                  title: String(localized: "Scanned QR is no talerURI"),
                                message: scannedURL.absoluteString,
                               copyable: true) {
                            scannedSomething = false
                            dismissTop(stack.push())
                        }
                    }
                } else {
                    ErrorView(stack.push(),
                              title: String(localized: "Scanned QR is no URL"),
                            message: scannedCode,
                           copyable: true
                    ) {
                        scannedSomething = false
                        dismissTop(stack.push())
                    }
                }
            } else {
                let codeScannerView = CodeScannerView(codeTypes: [AVMetadataObject.ObjectType.qr],
                                                 showViewfinder: true,
                                                      isTorchOn: isTorchOn
                ) { response in
                    let closingAnnouncement: String
                    switch response {
                        case .success(let result):
                            symLog.log("Found code: \(result.string)")
                            scannedSomething = true
                            scannedCode = result.string
                            closingAnnouncement = String(localized: "QR code recognized", comment: "a11y")
                        case .failure(let error):
                            // TODO: errorAlert
                            scannedSomething = false
                            model.setError(error)
                            closingAnnouncement = errorAnnouncement
                    }
                        announce(closingAnnouncement)
                }

                if minimalistic {
                    codeScannerView
                        .onTapGesture { isTorchOn.toggle() }
                } else if #available(iOS 16.4, *) {
                    codeScannerView
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    dismissTop(stack.push())
                                } label: {
                                    Image(systemName: XMARK)
                                }
                                .accessibilityLabel(Text("Dismiss QR scanner", comment: "a11y"))
//                                .accessibilityHidden(true)      // VoiceOver has its own "Dismiss Popup" button
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                let a11yValue = isTorchOn ? String(localized: "on", comment: "a11y")
                                                          : String(localized: "off", comment: "a11y")
                                Button {
                                    isTorchOn.toggle()
                                } label: {
                                    Image(systemName: isTorchOn ? LIGHT_ON : LIGHT_OFF)
                                }
                                .accessibilityLabel(Text("Torch for QR code scanning", comment: "a11y"))
                                .accessibilityValue(Text(a11yValue))
                            }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.gray)
                        .toolbarBackground(.visible)
//                        .toolbarBackground(.hidden)
                } else {
                    codeScannerView
                        .onTapGesture { isTorchOn.toggle() }
                }
            }
        }
    }
}
