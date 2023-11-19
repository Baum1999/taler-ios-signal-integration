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

    let exchange: Exchange
    @Binding var amountToTransfer: Amount

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("iconOnly") var iconOnly: Bool = false

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

        ScrollView {
            VStack {
                CurrencyInputView(amount: $amountToTransfer,
                               available: nil,
                                   title: iconOnly ? String(localized: "How much:")
                                                   : String(localized: "Amount to withdraw:"))
                let someCoins = SomeCoins(details: withdrawalAmountDetails)
                QuiteSomeCoins(someCoins: someCoins,
                           shouldShowFee: true,           // TODO: set to false if we never charge withdrawal fees
                                currency: currency,
                            currencyInfo: currencyInfo,
                         amountEffective: withdrawalAmountDetails?.amountEffective)
                Text(exchange.exchangeBaseUrl.trimURL())
                    .multilineTextAlignment(.center)
                    .accessibilityFont(.body)

                let disabled = amountToTransfer.isZero || someCoins.invalid || someCoins.tooMany
                if !disabled {
//                    agePicker

                    if let tosAccepted = withdrawalAmountDetails?.tosAccepted {
                        if tosAccepted {
//                            let restrictAge: Int? = (selectedAge == 0) ? nil
//                                                                       : selectedAge
//let _ = print(selectedAge, restrictAge)
                            NavigationLink(destination: LazyView {
                                ManualWithdrawDone(stack: stack.push(),
                                                exchange: exchange,
                                        amountToTransfer: amountToTransfer)
//                                              restrictAge: restrictAge)
                            }) {
                                Text("Confirm Withdrawal")      // VIEW_WITHDRAW_ACCEPT
                            }
                            .buttonStyle(TalerButtonStyle(type: .prominent))
                            .padding(.horizontal)
                        } else {
                            ToSButtonView(stack: stack.push(),
                                exchangeBaseUrl: exchange.exchangeBaseUrl,
                                         viewID: VIEW_WITHDRAW_TOS,
                                            p2p: false)
                        }
                    }
                } // disabled
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAWAL, stack: stack.push())
        }
        .task(id: amountToTransfer.value) { // re-run this whenever amountToTransfer changes
            if !amountToTransfer.isZero {
                do {
                    withdrawalAmountDetails = try await model.loadWithdrawalDetailsForAmountM(exchange.exchangeBaseUrl,
                                                                                              amount: amountToTransfer)
//                  agePicker.setAges(ages: withdrawalAmountDetails?.ageRestrictionOptions)
                } catch {    // TODO: error
                    symLog.log(error.localizedDescription)
                    withdrawalAmountDetails = nil
                }
            }
        }
    }
}
// MARK: -
#if DEBUG
struct ManualWithdraw_Previews: PreviewProvider {
  struct StateContainer : View {
    @State private var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 510)
    @State private var details = WithdrawalAmountDetails(tosAccepted: false,
                                                           amountRaw: Amount(currency: LONGCURRENCY, cent: 510),
                                                     amountEffective: Amount(currency: LONGCURRENCY, cent: 500),
                                                           paytoUris: [],
                                               ageRestrictionOptions: [],
                                                            numCoins: 6)
    var body: some View {
        let exchange = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
                                       currency: LONGCURRENCY,
                                      paytoUris: [],
                                      tosStatus: .pending,
                            exchangeEntryStatus: .preset,
                           exchangeUpdateStatus: .initial,
                          ageRestrictionOptions: [])
        ManualWithdraw(stack: CallStack("Preview"),
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
