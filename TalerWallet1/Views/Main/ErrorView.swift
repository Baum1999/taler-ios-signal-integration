/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct ErrorView: View {
    private let symLog = SymLogV(0)

    let errortext: String?

    var body: some View {
        
        Text(errortext ?? "Couldn't load Wallet-Core!")
    }
}

struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorView(errortext: EMPTYSTRING)
    }
}
