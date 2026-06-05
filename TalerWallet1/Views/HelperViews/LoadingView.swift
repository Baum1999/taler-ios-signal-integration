/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct LoadingView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scopeInfo: ScopeInfo?
    let message: String?

//    let backButtonHidden: Bool
    let navTitle = String(localized: "Loading…")

    @State private var rotationEnabled = true

    var body: some View {
        let view = VStack(alignment: .center) {
            Spacer()
            RotatingTaler(size: 100,
                      progress: true,                 // VoiceOver "In progress"
                          once: false,
               rotationEnabled: $rotationEnabled)
                .onTapGesture(count: 1) {
                    rotationEnabled.toggle()
                }
            Spacer()
            if let scopeInfo {
                if let urlStr = scopeInfo.url {
                    Text(urlStr.trimURL)
                } else {
                    Text(scopeInfo.currency)
                }
                Spacer()
            }
            if let message {
                Text(message)
            } else {
                Text(EMPTYSTRING)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .talerFont(.title)
        .navigationTitle("Loading…")
        .background(FullBackground())
        if #available(iOS 17.0, *) {
            view.toolbarTitleDisplayMode(.inlineLarge)
        } else {
            view
        }

    }
}
// MARK: -
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoadingView(stack: CallStack("Loading"), scopeInfo: nil, message: "test message")  // , backButtonHidden: true)
                .navigationBarTitleDisplayMode(.automatic)
        }.navigationViewStyle(.stack)
    }
}
