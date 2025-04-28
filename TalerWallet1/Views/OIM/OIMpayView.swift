/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

fileprivate func intValue(_ amount: Amount?) -> UInt64 {
    if let amount {
        if !amount.isZero {
            let int = amount.integer * 100              // TODO: currency specs instead of 100
            let frac = amount.fraction / 1_000_000      // drop 6 zeroes
            return int + UInt64(frac)
        }
    }
    return 0
}

// MARK: -
@available(iOS 16.4, *)
struct OIMpayView: View {
    let stack: CallStack
    let amount: Amount?
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)

    @EnvironmentObject private var wrapper: NamespaceWrapper

    @StateObject private var cash = OIMcash()
    @State private var amountVal: UInt64 = 0
    @State private var tappedVal: UInt64 = 0

    var body: some View {
//        let _ = Self._printChanges()
        let currency = cash.currency

        OIMbackground() {
            VStack {
                Spacer()
                OIMlineView(stack: stack.push(),
                             cash: cash,
                        amountVal: $amountVal,
                        tappedVal: $tappedVal,
                          canEdit: true)
                .matchedGeometryEffect(id: "OIMline", in: wrapper.namespace,isSource: true)
                Spacer()
            }
#if DEBUG
            .border(.red)
#endif
        }
        .task {
            amountVal = intValue(amount)
        }

    }
}
