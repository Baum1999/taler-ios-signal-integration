/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called by either the user tapping "Withdraw Coins" in the exchange list
// or from WithdrawExchangeV after a withdraw-exchange QR was scanned
struct ManualWithdraw: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let exchangeBaseUrl: String
    @Binding var amountToTransfer: Amount

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("iconOnly") var iconOnly: Bool = false

    @State private var withdrawalAmountDetails: WithdrawalAmountDetails? = nil
    @State private var exchange: Exchange? = nil
//    @State var ageMenuList: [Int] = []
//    @State var selectedAge = 0

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
      Group {
        if let exchange {
            let currency = exchange.scopeInfo?.currency
                        ?? exchange.currency
                        ?? String(localized: "Unknown", comment: "unknown currency")
            let currencyInfo = controller.info(for: currency, controller.currencyTicker)
            let navTitle = String(localized: "NavTitle_Withdraw (currency)", defaultValue: "Withdraw \(currency)")
//          let agePicker = AgePicker(ageMenuList: $ageMenuList, selectedAge: $selectedAge)

            let someCoins = SomeCoins(details: withdrawalAmountDetails)
//          let restrictAge: Int? = (selectedAge == 0) ? nil
//                                                     : selectedAge
//  let _ = print(selectedAge, restrictAge)
            let destination = LazyView {
                ManualWithdrawDone(stack: stack.push(),
                                exchange: exchange,
                        amountToTransfer: amountToTransfer)
//                           restrictAge: restrictAge)
            }
            let disabled = amountToTransfer.isZero || someCoins.invalid || someCoins.tooMany
            let tosAccepted = exchange.tosStatus == .accepted
            ScrollView { VStack(alignment: .trailing) {
                Text("via \(exchange.exchangeBaseUrl.trimURL())")
                    .multilineTextAlignment(.center)
                    .accessibilityFont(.body)
                if tosAccepted {
                    CurrencyInputView(amount: $amountToTransfer,
                                   available: nil,
                                       title: iconOnly ? String(localized: "Amount:")
                                                       : String(localized: "Amount to withdraw:"),
                              shortcutAction: nil)
                        .padding(.top)
                    QuiteSomeCoins(someCoins: someCoins,
                               shouldShowFee: true,           // TODO: set to false if we never charge withdrawal fees
                                    currency: currency,
                                currencyInfo: currencyInfo,
                             amountEffective: withdrawalAmountDetails?.amountEffective)
//                  agePicker
                    NavigationLink(destination: destination) {
                        Text("Confirm Withdrawal")      // VIEW_WITHDRAW_ACCEPT
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .disabled(disabled)
                    .padding(.top)
                } else {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: exchange.exchangeBaseUrl,
                                 viewID: VIEW_WITHDRAW_TOS,         // TODO: YIKES might be withdraw-exchange
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
        } else {
            LoadingView(url: nil, message: exchangeBaseUrl.trimURL())
        }
      } .task(id: amountToTransfer.value) { // re-run this whenever amountToTransfer changes
            symLog.log("getExchangeByUrl(\(exchangeBaseUrl))")
          if exchange == nil || exchange?.tosStatus != .accepted {
                if let exc = await model.getExchangeByUrl(url: exchangeBaseUrl) {
                    exchange = exc
                } else {
                    // TODO: Error "Can't get Exchange Info"
                }
            }
            if !amountToTransfer.isZero {
                do {
                    let details = try await model.loadWithdrawalDetailsForAmountM(exchangeBaseUrl,
                                                                           amount: amountToTransfer)
                    withdrawalAmountDetails = details
//                    agePicker.setAges(ages: withdrawalAmountDetails?.ageRestrictionOptions)
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

        var body: some View {
            ManualWithdraw(stack: CallStack("Preview"),
                 exchangeBaseUrl: DEMOEXCHANGE,
                amountToTransfer: $amountToTransfer)
        }
    }

    static var previews: some View {
        StateContainer()
    }
}
#endif
