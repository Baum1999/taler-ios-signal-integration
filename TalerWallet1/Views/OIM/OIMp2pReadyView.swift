/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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
    let scope: ScopeInfo
    let action: () -> Void

    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var sending = false              // user tapped on Send
    @State private var appeared = false


    var body: some View {
//        let _ = Self._printChanges()

        OIMbackground() {
            VStack {
                if let transactionId {
                    Text(verbatim: "transaction sent")
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
