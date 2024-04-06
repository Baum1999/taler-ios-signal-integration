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
//    @Binding var depositIBAN: String
//    @Binding var accountHolder: String
    let amountAvailable: Amount?
    let currency: String                        // this is the currency to be used
    @Binding var amountToTransfer: Amount       // does still have the wrong currency

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
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
        let showToS = LazyView {
            WithdrawTOSView(stack: stack.push(),
                  exchangeBaseUrl: baseURL,
                           viewID: VIEW_WITHDRAW_TOS,
                     acceptAction: nil)         // pop back to here
        }
        Group {
            NavigationLink(destination: showToS) {
                VStack(alignment: .leading) {
                    Text(baseURL.trimURL())
                        .talerFont(.headline)
                    if !minimalistic {
                        Text("Terms of Service")  // VIEW_WITHDRAW_TOS
                            .talerFont(.body)
                    }
                }
            }
            .listRowSeparator(.hidden)

            DepositWithdrawV(stack: stack.push(),
                         scopeInfo: exchange.scopeInfo,
                   amountAvailable: amountAvailable,
                          currency: currency,
                  amountToTransfer: $amountToTransfer)
        }
        .task {
            if controller.hasInfo(for: currency) == nil {
                symLog.log("fetching info for \(currency)")
                // FIXME: remove fake ScopeInfo once the REAL one is in exchange.scopeInfo
                let scopeInfo = exchange.scopeInfo
                             ?? ScopeInfo(type: .global, currency: currency)
                if let info = try? await model.getCurrencyInfoM(scope: scopeInfo, delay: delay) {
//                    logger.info("got info: \(scope.currency, privacy: .public)")
                    await controller.setInfo(info)
                }
            }
        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct ExchangeRow_Container : View {
    @State private var amountToPreview = Amount(currency: LONGCURRENCY, cent: 1234)
    @State private var depositIBAN = "DE1234567890"
    @State private var accountHolder = "Marc Stibane"

//    let amount = Amount(currency: LONGCURRENCY, cent: 123456)
    var body: some View {
        let scopeInfo = ScopeInfo(type: .exchange, currency: LONGCURRENCY)
        let exchange1 = Exchange(exchangeBaseUrl: ARS_AGE_EXCHANGE,
                                       scopeInfo: scopeInfo,
                                       paytoUris: [],
                                       tosStatus: .pending,
                             exchangeEntryStatus: .preset,
                            exchangeUpdateStatus: .initial,
                           ageRestrictionOptions: [12,16])
        let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                       scopeInfo: scopeInfo,
                                       paytoUris: [],
                                       tosStatus: .proposed,
                             exchangeEntryStatus: .ephemeral,
                            exchangeUpdateStatus: .ready,
                           ageRestrictionOptions: [])
        ExchangeRowView(stack: CallStack("Preview"),
                     exchange: exchange1,
              amountAvailable: Amount(currency: LONGCURRENCY, cent: 5000),      // 50,00
                     currency: LONGCURRENCY,
//                  depositIBAN: $depositIBAN,
//                accountHolder: $accountHolder,
             amountToTransfer: $amountToPreview)
    }
}

fileprivate struct ExchangeRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ExchangeRow_Container()
        }
    }
}
#endif
