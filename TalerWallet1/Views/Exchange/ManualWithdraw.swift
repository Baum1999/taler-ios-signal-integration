/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called by the user tapping "Withdraw Coins" in the exchange list
struct ManualWithdraw: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

//    let url: URL?
//    let exchange: Exchange?
    let exchange: Exchange
    @Binding var amountToTransfer: Amount

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("iconOnly") var iconOnly: Bool = false

    @State var tosAccepted = false
    @State var withdrawalAmountDetails: WithdrawalAmountDetails? = nil
//    @State var ageMenuList: [Int] = []
//    @State var selectedAge = 0

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = exchange.scopeInfo?.currency ?? exchange.currency ?? String(localized: "Unknown", comment: "unknown currency")
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let navTitle = String(localized: "NavTitle_Withdraw (currency)", defaultValue: "Withdraw \(currency)")
//        let agePicker = AgePicker(ageMenuList: $ageMenuList, selectedAge: $selectedAge)

        let someCoins = SomeCoins(details: withdrawalAmountDetails)
//      let restrictAge: Int? = (selectedAge == 0) ? nil
//                                                 : selectedAge
//  let _ = print(selectedAge, restrictAge)
        let destination = LazyView {
            ManualWithdrawDone(stack: stack.push(),
                            exchange: exchange,
                    amountToTransfer: amountToTransfer)
//                       restrictAge: restrictAge)
        }
        let disabled = amountToTransfer.isZero || someCoins.invalid || someCoins.tooMany
        ScrollView { VStack(alignment: .trailing) {
            Text("via \(exchange.exchangeBaseUrl.trimURL())")
                .multilineTextAlignment(.center)
                .accessibilityFont(.body)
            CurrencyInputView(amount: $amountToTransfer,
                           available: nil,
                               title: iconOnly ? String(localized: "How much:")
                                               : String(localized: "Amount to withdraw:"))
                .padding(.top)
            QuiteSomeCoins(someCoins: someCoins,
                       shouldShowFee: true,           // TODO: set to false if we never charge withdrawal fees
                            currency: currency,
                        currencyInfo: currencyInfo,
                     amountEffective: withdrawalAmountDetails?.amountEffective)
//          agePicker
            if tosAccepted {
                NavigationLink(destination: destination) {
                    Text("Confirm Withdrawal")      // VIEW_WITHDRAW_ACCEPT
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
                .padding(.top)
            } else {
                ToSButtonView(stack: stack.push(),
                    exchangeBaseUrl: exchange.exchangeBaseUrl,
                             viewID: VIEW_WITHDRAW_TOS,
                                p2p: false)
                .padding(.top)
            }
        } } // ScrollVStack
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_WITHDRAWAL, stack: stack.push())
            symLog.log("❗️ \(navTitle) onAppear")
        }
        .onDisappear {
            symLog.log("❗️ \(navTitle) onDisappear")
        }
        .task(id: amountToTransfer.value) { // re-run this whenever amountToTransfer changes
            do {
                let amount = amountToTransfer.isZero ? Amount(currency: currency, cent: 100)
                                                     : amountToTransfer
//              if amountToTransfer.isZero {
//                  tosAccepted = GetTosStatus(exchange.exchangeBaseUrl)
//              } else {
                    let details = try await model.loadWithdrawalDetailsForAmountM(exchange.exchangeBaseUrl,
                                                                                  amount: amount)
                    tosAccepted = details.tosAccepted
                    withdrawalAmountDetails = amountToTransfer.isZero ? nil : details
//                  agePicker.setAges(ages: withdrawalAmountDetails?.ageRestrictionOptions)
//              }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                withdrawalAmountDetails = nil
            }
        }
    }
}
// MARK: -
#if DEBUG
struct ManualWithdraw_Previews: PreviewProvider {
  struct StateContainer : View {
    @State private var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 510)

      var body: some View {
        let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, url: DEMOEXCHANGE, currency: LONGCURRENCY)
        let exchange = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
                                       currency: LONGCURRENCY,
                                      paytoUris: [],
                                      tosStatus: .pending,
                            exchangeEntryStatus: .preset,
                           exchangeUpdateStatus: .initial,
                          ageRestrictionOptions: [])
        let details = WithdrawalAmountDetails(tosAccepted: false,
                                                amountRaw: Amount(currency: LONGCURRENCY, cent: 510),
                                          amountEffective: Amount(currency: LONGCURRENCY, cent: 500),
                                                 numCoins: 6,
//                                              paytoUris: [],
                                   withdrawalAccountsList: [],
                                    ageRestrictionOptions: [],
                                                scopeInfo: scopeInfo)
        ManualWithdraw(stack: CallStack("Preview"),
//                         url: nil,
                    exchange: exchange,
            amountToTransfer: $amountToTransfer,
     withdrawalAmountDetails: details)
    }
  }

    static var previews: some View {
        StateContainer()
    }
}
#endif
