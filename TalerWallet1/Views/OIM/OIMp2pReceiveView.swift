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
struct OIMp2pReceiveView: View {
    let stack: CallStack
    let cash: OIMcash
    let available: Amount?
    @Binding var peerPushCreditResponse: PreparePeerPushCreditResponse?
    @Binding var fwdButtonTapped: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var amount: Amount?
    @State private var amountVal: UInt64 = 0
    @State private var appeared = false
    @State private var ignoreTapped: UInt64 = 0

    var body: some View {
//        let _ = Self._printChanges()
        let currency = cash.currency
        let noteBase = currency.noteBase
        let isSierra = noteBase == "SLE"

        OIMnavBack(stack: stack.push(),
            currencyName: noteBase,
                 isFinal: false,
                isSierra: isSierra,
               isSending: false,
                  amount: amount,
                  action: { }
        ) {
            Group {
                if let peerPushCreditResponse {
                    let terms = peerPushCreditResponse.contractTerms
                    let goal = terms.icon_id
                    let effective = terms.amount
                    VStack {
                        OIMtitleView(cash: cash,
                                   amount: effective,
                                isSending: false,
                                  history: false,
                             secondAmount: nil)
                        Spacer()
                        if let goal {
                            Image(goal)
                                .resizable()
                                .background(Color.white)
                                .scaledToFit()
                                .matchedGeometryEffect(id: goal, in:     wrapper.namespace)
                        }

                        OIMlineView(stack: stack.push(),
                                     cash: cash,
                                amountVal: $amountVal,
                                tappedVal: $ignoreTapped,
                                  canEdit: false)
                        Spacer()
                    }
                    .opacity(appeared ? 1.0 : 0.01)
                    .scaleEffect(appeared ? 1.0 : 0.3)
                    .task {
                        amount = effective
                        amountVal = effective.centValue
                        withAnimation(.basic1) {
                            appeared = true
                        }
                    }
                } else {
                    Text(verbatim: "loading")
                }
            }
        }
    }
}
