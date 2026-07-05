/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import taler_swift


#if GNU_TALER
struct DevExperimentView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let url: URL

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller

    @State private var finished = false

    @MainActor
    private func viewDidLoad() async {
        symLog.log(".task \(url.absoluteString)")
        try? await model.setConfig(setTesting: true)
        try? await model.devExperimentT(url.absoluteString)
        finished = true
    }

    var body: some View {
        if finished {
            VStack {
                Spacer()
                Text(url.absoluteString)
                    .talerFont(.title2)
                    .padding()
                Spacer()
                let title = "Finished"
                Button(title) {
                    dismiss()
                }
                Spacer()
            }
        } else {
            LoadingView(stack: stack.push(), scopeInfo: nil, message: url.absoluteString)
                .task { await viewDidLoad() }
        }
    }
}
#endif
