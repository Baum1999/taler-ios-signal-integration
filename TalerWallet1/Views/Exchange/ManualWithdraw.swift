/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct ManualWithdraw: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Withdraw Coins")

    var exchange: Exchange
    @ObservedObject var model: WithdrawModel
    @Binding var centsToTransfer: UInt64

    @State var manualWithdrawalDetails: ManualWithdrawalDetails? = nil
//    @State var numCoins: Int = 0

    // returns numCoins, 0 if invalid, -1 if unknown
    //         either fees or empty string
    private func numAndFee(detailsForAmount: ManualWithdrawalDetails?) -> (Int, String) {
        do {
            if let details = detailsForAmount {
                let fee = try details.amountRaw - details.amountEffective
                return (details.numCoins ?? -1,    // either the number of coins, or unknown
                        fee.isZero ? "" : fee.readableDescription)
            }
        } catch {}
        symLog.log("invalid")
        return (0, "")      // invalid
    }
    @State var ageMenuList: [Int] = []
    @State var selectedAge = 0


    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = exchange.currency!
        let currencyField = CurrencyField(value: $centsToTransfer, currency: currency) // becomeFirstResponder

        ScrollView {
            Text("from \(exchange.exchangeBaseUrl.trimURL())")
                .padding(.top)
                .font(.title3)
            CurrencyInputView(currencyField: currencyField, title: String(localized: "Amount to withdraw:"))

            let (numCoins, fee) = numAndFee(detailsForAmount: manualWithdrawalDetails)
            let unknown   = (numCoins < 0)
            let invalid   = (numCoins == 0)
            let manyCoins = (numCoins > 99)
            let quiteSome = (numCoins > 199)
            let tooMany   = (numCoins > 999)
            let hasFee    = (fee.count > 0)
            let shownFee = hasFee ? String(localized: "- \(fee)") : String(localized: "No")
            Text(invalid ? "invalid amount"
               : tooMany ? "too many coins for a single withdrawal"
                         : "\(shownFee) withdrawal fee")
                .foregroundColor((invalid || tooMany || hasFee) ? .red : .primary)
                .padding()

            if !invalid {
                HStack {
                    Text(unknown ? "Some" : "\(numCoins)")
                        .foregroundColor(quiteSome ? .red : .primary)
                    Text(tooMany ? "coins" : "coins to obtain:")
                        .foregroundColor(tooMany ? .red : .primary)

                    Spacer()
                    if !tooMany {
                        let effective = manualWithdrawalDetails?.amountEffective ?? Amount(currency: currency, value: 0)
                        Text(effective.readableDescription)
                    }
                } // xx coins to obtain:    YYY currency
                .padding(.top)
//                .font(.title3)

                if !tooMany {
                    if manyCoins {
                        Text(quiteSome ? "Warning: It will take quite some time\nto generate this many coins!"
                                       : "Warning: It will take some time\nto generate this many coins.")
                        .multilineTextAlignment(.leading)
                        .padding(.top, 6)
                        .foregroundColor(quiteSome ? .red : .primary)
                    } // warnings

                    if ageMenuList.count > 1 {
                        HStack {
                            Text("If this wallet belongs to a child or teenager, the generated coins should be age-restricted:")
                                .multilineTextAlignment(.leading)
                                .font(.footnote)
                            Spacer()
                        }.padding(.top)
                        Picker("Select age", selection: $selectedAge) {
                            ForEach($ageMenuList, id: \.self) { item in
                                let index = item.wrappedValue
                                Text((index == 0) ? "unlimited"
                                                  : "\(index) years").tag(index)
                            }
                        }
                    }
                    if let tosAcc = manualWithdrawalDetails?.tosAccepted {
                        if tosAcc {
                            let restrictAge: Int? = (selectedAge == 0) ? nil
                                                                       : selectedAge
let _ = print(selectedAge, restrictAge)
                            NavigationLink(destination: LazyView {
                                ManualWithdrawDone(exchange: exchange,
                                                      model: model,
                                            centsToTransfer: centsToTransfer,
                                                restrictAge: restrictAge)
                            }) {
                                Text("Confirm Withdrawal")      // VIEW_WITHDRAW_ACCEPT
                            }.buttonStyle(TalerButtonStyle(type: .prominent))
                        } else {
                            NavigationLink(destination: LazyView {
                                WithdrawTOSView(exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                          model: model,
                                                         viewID: VIEW_WITHDRAW_TOS,
                                                   acceptAction: nil)         // pop back to here
                            }) {
                                Text("Check Terms of Service")  // VIEW_WITHDRAW_TOS
                            }.buttonStyle(TalerButtonStyle(type: .prominent))
                        }
                    }
                } // tooMany
            } // invalid
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(navTitle)
        .padding(.horizontal)
        .onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAWAL)
        }
        .task(id: centsToTransfer) {
            let amount = Amount.amountFromCents(currency, centsToTransfer)
            do {
                manualWithdrawalDetails = try await model.loadWithdrawalDetailsForAmountM(exchange.exchangeBaseUrl, amount: amount)
                if let ageRestrictions = manualWithdrawalDetails?.ageRestrictionOptions {
                    var ages = ageRestrictions
                    let nonzero = ages.count > 0        // need at least 1 value from exchange which is not 0
                    if nonzero {
                        if ages[0] != 0 {               // ensure that the first age is "0"
                            ages.insert(0, at: 0)       // if not, insert "0" at position 0
                        }
                        if selectedAge >= ages.count {  // check for out of bounds
                            selectedAge = 0
                        }
                    } else {
                        selectedAge = 0             // first ensure that selected is not out of bounds
                    }
print(ages)
                    ageMenuList = ages              // set State (will update view)
                }
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
    @State private var manualWithdrawalDetails = ManualWithdrawalDetails(amountRaw: try! Amount(fromString: LONGCURRENCY + ":5.1"),
                                                                   amountEffective: try! Amount(fromString: LONGCURRENCY + ":5.0"),
                                                                         paytoUris: [],
                                                                       tosAccepted: false,
                                                             ageRestrictionOptions: [],
                                                                          numCoins: 6)

    var body: some View {
        let model = WithdrawModel.model(baseURL: DEMOEXCHANGE)
        let exchange = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
                                       currency: LONGCURRENCY,
                                      paytoUris: [],
                                      tosStatus: "tosStatus",
                                 exchangeStatus: "exchangeStatus",
                          ageRestrictionOptions: [],
                                      permanent: false)
        ManualWithdraw(exchange: exchange,
                          model: model,
                centsToTransfer: $centsToTransfer,
        manualWithdrawalDetails: manualWithdrawalDetails)
    }
}

struct ManualWithdraw_Previews: PreviewProvider {
    static var previews: some View {
        ManualWithdraw_Container()
    }
}
#endif
