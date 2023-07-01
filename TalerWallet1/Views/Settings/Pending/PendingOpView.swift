/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct PendingOpView: View {
    var pendingOp: PendingOperation
    @State var polling: Bool = false
    @State var liveliness: Bool = false
    @State var isDue: Bool = false

    var body: some View {
        Section {
            if let baseURL = pendingOp.exchangeBaseUrl {
                Text(baseURL)
            }
            Text(pendingOp.id)
                .font(.caption)
            let isLongPolling = "isLongPolling"
            Toggle(isLongPolling, isOn: $polling)
                .disabled(true)
            let givesLifeness = "givesLifeness"
            Toggle(givesLifeness, isOn: $liveliness)
                .disabled(true)
            let isDue = "isDue"
            Toggle(isDue, isOn: $isDue)
                .disabled(true)
            let dateString = TalerDater.dateString(from: pendingOp.timestampDue)
            Text(dateString)
        } header: {
            Text(pendingOp.type)
                .font(.title2)
        }
//        .textCase(nil)    // don't capitalize
        .onAppear {
            polling = pendingOp.isLongpolling
            liveliness = pendingOp.givesLifeness
            isDue = pendingOp.isDue
        }
    }
}
// MARK: -
#if DEBUG
struct PendingOpView_Previews: PreviewProvider {
    static var pending1 = PendingOperation(type: "exchange-check-refresh",
                                exchangeBaseUrl: DEMOEXCHANGE,
                                             id: "exchange-update:" + DEMOEXCHANGE,
                                  isLongpolling: false,
                                  givesLifeness: true,
                                          isDue: false,
                                   timestampDue: Timestamp(from:1700000000000))
    static var previews: some View {
        List {
            PendingOpView(pendingOp: pending1)
        }
    }
}
#endif
