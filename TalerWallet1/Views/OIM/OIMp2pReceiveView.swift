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

    var body: some View {
//        let _ = Self._printChanges()
        let currency = cash.currency
        OIMnavBack(stack: stack.push(),
                   chest: currency.chest,
                    type: .requestP2P,          // TODO: define receive
                 isFinal: false,
               isSending: false,
                  action: { },
             actDisabled: amount?.isZero ?? true
        ) {
            Group {
                if let peerPushCreditResponse {
                    let terms = peerPushCreditResponse.contractTerms
                    let goal = terms.icon_id
                    let effective = terms.amount
                    VStack {
                        OIMtitleView(cash: cash,
                                   amount: effective,
                                  history: false,
                             secondAmount: nil)
                        Spacer()
                        if let goal {
                            Image(goal)
                                .resizable()
                                .background(Color.white)
                                .scaledToFit()
                                .matchedGeometryEffect(id: goal, in: wrapper.namespace)
                        }

                        OIMlineView(stack: stack.push(),
                                     cash: cash,
                                amountVal: $amountVal,
                                  canEdit: false)
                        Spacer()
                    }
                    .opacity(appeared ? 1 : INVISIBLE)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .task {
                        amount = effective
                        amountVal = effective.centValue                         // TODO: centValue factor
                        cash.update2(amountVal)
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
