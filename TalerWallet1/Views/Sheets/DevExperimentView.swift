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

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller


    @MainActor
    private func viewDidLoad() async {
        symLog.log(".task \(url.absoluteString)")
        try? await model.setConfig(setTesting: true)
        try? await model.devExperimentT(talerUri: url.absoluteString)
    }

    var body: some View {
        LoadingView(stack: stack.push(), scopeInfo: nil, message: url.host)
            .task { await viewDidLoad() }
    }
}
#endif
