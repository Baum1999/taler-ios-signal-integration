/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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
    @State private var buttonSelected: Int? = nil

    func selectAndUpdate(_ button: Int) {
        amountToTransfer.setCurrency(currency)
        buttonSelected = button      // will trigger NavigationLink
        // TODO: after user tapped a button, while navigation animation runs, contact Exchange to update Fees
        // cannot be uncommented yet since there is no scopeInfo
//        Task { // runs on MainActor
//            do {
//                try await model.updateExchange(scopeInfo: balance.scopeInfo)
//            } catch {    // TODO: error handling - couldn't updateExchange
//                //                symLog.log("error: \(error)")
//            }
//        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
        let delay: UInt = 0     // set to 5 to test delayed currency information
#else
        let delay: UInt = 0
#endif
        let depositTitle0 = String(localized: "DepositButton_Short", defaultValue: "Deposit",
                                   comment: "Abbreviation of `Deposit (currency)´")
        let depositTitle1 = String(localized: "Deposit\t\(currency)",
                                   comment: "Button `Deposit (currency)´, must have ONE \\t and ONE %@")

        let withdrawTitle0 = String(localized: "WithdrawButton_Short", defaultValue: "Withdraw",
                                    comment: "Abbreviation of `Withdraw (currency)´")
        let withdrawTitle1 = String(localized: "Withdraw\t\(currency)",
                                    comment: "Button `Withdraw (currency)´, must have ONE \\t and ONE %@")
        let baseURL = exchange.exchangeBaseUrl
        
        let deposit = LazyView {
            DepositIbanV(stack: stack.push(),
                      feeLabel: nil,
                  feeIsNotZero: nil,
               amountAvailable: amountAvailable,
//                   depositIBAN: $depositIBAN,
//                 accountHolder: $accountHolder,
              amountToTransfer: $amountToTransfer)
        }
        let manualWithdraw = LazyView {
            ManualWithdraw(stack: stack.push(),
                 exchangeBaseUrl: baseURL,
                amountToTransfer: $amountToTransfer)
        }
        let showToS = LazyView {
            WithdrawTOSView(stack: stack.push(),
                  exchangeBaseUrl: baseURL,
                           viewID: VIEW_WITHDRAW_TOS,
                     acceptAction: nil)         // pop back to here
        }
        let disableDeposit = false     // TODO: availableAmount.isZero
        let twoRowButtons = TwoRowButtons(sendTitle: minimalistic ? depositTitle0 : depositTitle1,
                                          recvTitle: minimalistic ? withdrawTitle0 : withdrawTitle1,
                                     fitsSideBySide: false,
                                          lineLimit: 5,
                                       sendDisabled: disableDeposit,
                                         sendAction: { selectAndUpdate(1) },
                                         recvAction: { selectAndUpdate(2) })
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
            .background( Group {
                NavigationLink(destination: deposit, tag: 1, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
                NavigationLink(destination: manualWithdraw, tag: 2, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
            })
            .listRowSeparator(.hidden)
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: HSPACING) {
                        twoRowButtons.makeCopy(fitsSideBySide: true)
                    }
                    VStack { twoRowButtons }
                }
            } else { // view for iOS 15
                VStack { twoRowButtons }
            }
        }
        .task {
            if controller.hasInfo(for: currency) == nil {
                symLog.log("fetching info for \(currency)")
                // FIXME: remove fake ScopeInfo once the REAL one is in exchange.scopeInfo
                let scopeInfo = exchange.scopeInfo
                             ?? ScopeInfo(type: .global, currency: currency)
                do {
                    let info = try await model.getCurrencyInfoM(scope: scopeInfo, delay: delay)
//                    logger.info("got info: \(scope.currency, privacy: .public)")
                    await controller.setInfo(info)
                } catch {    // TODO: error handling - couldn't get CurrencyInfo
//                    logger.error("Couldn't get info for: \(scope.currency, privacy: .public)\n\(error)")
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
