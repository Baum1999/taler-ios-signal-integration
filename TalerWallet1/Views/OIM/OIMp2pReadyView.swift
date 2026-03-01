/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

// MARK: -
@available(iOS 16.4, *)
struct OIMp2pReadyView: View {
    let stack: CallStack
    @Binding var transactionId: String?
    let talerTX: TalerTransaction
    let scope: ScopeInfo
    let action: () -> Void

    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var sending = false              // user tapped on Send
    @State private var appeared = false
    @State private var qrImage: UIImage? = nil

    var body: some View {
//        let _ = Self._printChanges()

        OIMbackground() {
            VStack {
                if let transactionId {
                    if talerTX.isPendingReady {
                        let details = talerTX.detailsToShow()
                        let keys = details.keys
                        if keys.contains(TALERURI) {
                            if let talerURI = details[TALERURI] {
                                if talerURI.count > 10 {
                                    Group {
                                        Spacer()
                                        let size = 240.0
                                        QRGeneratorView(text: talerURI, size: size, logo: nil, logoSize: size / 4, image: $qrImage)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .accessibilityLabel(Text("QR Code", comment: "a11y"))
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                } else {
                    LoadingView(stack: stack.push(),
                            scopeInfo: scope,
                              message: nil)
                }
            }
//              .border(.red)
        }.task {
            withAnimation(.basic1) {
                appeared = true
            }
        }
    }
}
