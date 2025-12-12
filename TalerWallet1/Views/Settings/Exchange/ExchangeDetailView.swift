/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

struct ExchangeDetailView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let exchange: Exchange

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var tabBarModel: TabBarModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
        let delay: UInt = 0     // set to 5 to test delayed currency information
#else
        let delay: UInt = 0
#endif
        let baseURL = exchange.exchangeBaseUrl
        let rowView = HStack {
            if !minimalistic {
                Text("Status:")
            }
            Text(exchange.exchangeUpdateStatus.rawValue)  // VIEW_WITHDRAW_TOS
        }
            .talerFont(.body)
        rowView

    }
}
// MARK: -
#if DEBUG
fileprivate struct ExchangeDetail_Previews: PreviewProvider {
    @MainActor
    struct BindingViewContainer : View {

        var body: some View {
            let scopeInfo = ScopeInfo(type: .exchange, currency: LONGCURRENCY)
            let exchange1 = Exchange(exchangeBaseUrl: ARS_AGE_EXCHANGE,
                                           masterPub: "masterPub",
                                           scopeInfo: scopeInfo,
                                           paytoUris: [],
                                           tosStatus: .pending,
                                 exchangeEntryStatus: .preset,
                                exchangeUpdateStatus: .initial,
                               ageRestrictionOptions: [12,16])
            let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                           masterPub: "masterPub",
                                           scopeInfo: scopeInfo,
                                           paytoUris: [],
                                           tosStatus: .proposed,
                                 exchangeEntryStatus: .ephemeral,
                                exchangeUpdateStatus: .ready,
                               ageRestrictionOptions: [])
            ExchangeDetailView(stack: CallStack("Preview"),
                         exchange: exchange1)
        }
    }

    @MainActor
    static var previews: some View {
        List {
            BindingViewContainer()
        }
    }
}
#endif
