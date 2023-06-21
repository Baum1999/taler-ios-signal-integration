/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called by the user tapping "Withdraw Coins" in the exchange list
struct ManualWithdraw: View {
    private let symLog = SymLogV()

    let exchange: Exchange
    @Binding var centsToTransfer: UInt64

    @EnvironmentObject private var model: WalletModel

    @State var manualWithdrawalDetails: ManualWithdrawalDetails? = nil

//    @State var ageMenuList: [Int] = []
//    @State var selectedAge = 0

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = exchange.currency!
        let navTitle = String(localized: "Withdraw \(currency)")
        let currencyField = CurrencyField(value: $centsToTransfer, currency: currency) // becomeFirstResponder
//        let agePicker = AgePicker(ageMenuList: $ageMenuList, selectedAge: $selectedAge)

        ScrollView {
            Text("from \(exchange.exchangeBaseUrl.trimURL())")
                .font(.title3)
            CurrencyInputView(currencyField: currencyField,
                              title: String(localized: "Amount to withdraw:"))

            let someCoins = SomeCoins(details: manualWithdrawalDetails)
            QuiteSomeCoins(someCoins: someCoins, shouldShowFee: true,
                           currency: currency, amountEffective: manualWithdrawalDetails?.amountEffective)

            if !someCoins.invalid {
                if !someCoins.tooMany {
//                    agePicker

                    if let tosAccepted = manualWithdrawalDetails?.tosAccepted {
                        if tosAccepted {
//                            let restrictAge: Int? = (selectedAge == 0) ? nil
//                                                                       : selectedAge
//let _ = print(selectedAge, restrictAge)
                            NavigationLink(destination: LazyView {
                                ManualWithdrawDone(exchange: exchange,
                                            centsToTransfer: centsToTransfer)
//                                                restrictAge: restrictAge)
                            }) {
                                Text("Confirm Withdrawal")      // VIEW_WITHDRAW_ACCEPT
                            }.buttonStyle(TalerButtonStyle(type: .prominent))
                        } else {
                            NavigationLink(destination: LazyView {
                                WithdrawTOSView(exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                         viewID: VIEW_WITHDRAW_TOS,
                                                   acceptAction: nil)         // pop back to here
                            }) {
                                Text("Check Terms of Service")  // VIEW_WITHDRAW_TOS
                            }.buttonStyle(TalerButtonStyle(type: .prominent))
                        }
                    }
                } // tooMany
            } // invalid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAWAL)
        }
        .task(id: centsToTransfer) {
            let amount = Amount.amountFromCents(currency, centsToTransfer)
            do {
                manualWithdrawalDetails = try await model.loadWithdrawalDetailsForAmountM(exchange.exchangeBaseUrl, amount: amount)
//                agePicker.setAges(ages: manualWithdrawalDetails?.ageRestrictionOptions)
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                manualWithdrawalDetails = nil
            }
        }
    }
}
// MARK: -
#if DEBUG
struct ManualWithdraw_Container : View {
    @State private var centsToTransfer: UInt64 = 510
    @State private var details = ManualWithdrawalDetails(tosAccepted: false,
                                                           amountRaw: try! Amount(fromString: LONGCURRENCY + ":5.1"),
                                                     amountEffective: try! Amount(fromString: LONGCURRENCY + ":5.0"),
                                                           paytoUris: [],
                                               ageRestrictionOptions: [],
                                                            numCoins: 6)
    var body: some View {
        let exchange = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
                                       currency: LONGCURRENCY,
                                      paytoUris: [],
                                      tosStatus: "tosStatus",
                                 exchangeStatus: "exchangeStatus",
                          ageRestrictionOptions: [],
                                      permanent: false)
        ManualWithdraw(exchange: exchange,
                centsToTransfer: $centsToTransfer,
        manualWithdrawalDetails: details)
    }
}

struct ManualWithdraw_Previews: PreviewProvider {
    static var previews: some View {
        ManualWithdraw_Container()
    }
}
#endif
