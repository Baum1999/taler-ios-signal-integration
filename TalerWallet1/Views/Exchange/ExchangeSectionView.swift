/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

/// This view shows the currency name in an exchange section
///         currency
/// [Deposit Coins]  [Withdraw Coins]
struct ExchangeSectionView: View {
    let stack: CallStack
    let currency: String                        // this is the currency to be used
    let exchanges: [Exchange]
    @Binding var amountToTransfer: Amount       // does still have the wrong currency

    func setCurrency() -> String {
        amountToTransfer.setCurrency(currency)
        return currency
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency2 = setCurrency()           // update currency in amountToTransfer
        Section {
            ForEach(exchanges) { exchange in
                ExchangeRowView(stack: stack.push(),
                             exchange: exchange,
                             currency: currency2,            // TODO: (balance.available) amount.isZero to disable Deposit-button
                     amountToTransfer: $amountToTransfer)
            }
        } header: {
            BarGraphHeader(stack: stack.push(), currency: currency)
        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct ExchangeSection_Previews: PreviewProvider {
fileprivate struct ExchangeRow_Container : View {
    @State private var amountToPreview = Amount(currency: LONGCURRENCY, cent: 1234)

//    let amount = Amount(currency: LONGCURRENCY, cent: 123456)
    var body: some View {
        let exchange1 = Exchange(exchangeBaseUrl: ARS_AGE_EXCHANGE,
                                        currency: LONGCURRENCY,
                                       paytoUris: [],
                                       tosStatus: .pending,
                             exchangeEntryStatus: .preset,
                            exchangeUpdateStatus: .initial,
                           ageRestrictionOptions: [12,16])
        let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                        currency: LONGCURRENCY,
                                       paytoUris: [],
                                       tosStatus: .proposed,
                             exchangeEntryStatus: .ephemeral,
                            exchangeUpdateStatus: .ready,
                           ageRestrictionOptions: [])
        ExchangeSectionView(stack: CallStack("Preview"), currency: LONGCURRENCY,
                            exchanges: [exchange1, exchange2],
                            amountToTransfer: $amountToPreview)
    }
}

    static var previews: some View {
        List {
            ExchangeRow_Container()
        }
    }
}
#endif
