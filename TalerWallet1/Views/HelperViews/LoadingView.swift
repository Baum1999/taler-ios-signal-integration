/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct LoadingView: View {
    private let symLog = SymLogV(0)
    let navTitle = String(localized: "Loading...")
    let backButtonHidden: Bool

    var body: some View {
        LaunchAnimationView()
            .navigationBarBackButtonHidden(backButtonHidden)
            .navigationTitle(navTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
//            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
    }
}
// MARK: -
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoadingView(backButtonHidden: true)
                .navigationBarTitleDisplayMode(.automatic)
        }.navigationViewStyle(.stack)
    }
}
