/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

struct ExchangeRowView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let exchange: Exchange
    let index: Int

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var navModel: NavigationModel
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
        let rowView = VStack(alignment: .leading) {
            Text(baseURL.trimURL)
                .talerFont(.headline)
            if !minimalistic {
                Text("Terms of Service")  // VIEW_WITHDRAW_TOS
                    .talerFont(.body)
            }
        }
        let cellView = HStack {
            rowView
            Spacer()
            Text(Image(systemName: "chevron.right"))
                .talerFont(.table)
                .foregroundColor(.secondary)
        }.background {           // only needed for .onTapGesture
            Color.gray.opacity(0.001)
        }
        let showToS = WithdrawTOSView(stack: stack.push(),
                            exchangeBaseUrl: baseURL,
                                     viewID: VIEW_WITHDRAW_TOS,
                               acceptAction: nil)         // pop back to here
        let actions = Group {
            NavLink(index, $navModel.tosView) { showToS }
        }

        Group {
//          NavigationLink(destination: showToS) { rowView }
            cellView
                .background(actions)
                .onTapGesture {
                    navModel.tosView = index
                }
//                .task {
//                    navModel.tosView = false
//                }
        }.listRowSeparator(.hidden)
    }
}
// MARK: -
#if DEBUG
fileprivate struct ExchangeRow_Previews: PreviewProvider {
    @MainActor
    struct BindingViewContainer : View {
        @State private var amountToPreview = Amount(currency: LONGCURRENCY, cent: 1234)
        @State private var depositIBAN = "DE1234567890"
        @State private var accountHolder = "Marc Stibane"
//        @State private var previewL: CurrencyInfo = CurrencyInfo.zero(LONGCURRENCY)

//    let amount = Amount(currency: LONGCURRENCY, cent: 123456)
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
            ExchangeRowView(stack: CallStack("Preview"),
                         exchange: exchange1,
                            index: 1)
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
