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
//    let amount: Amount
    let currency: String          // TODO: amount.currencyStr
    let exchanges: [Exchange]
    @Binding var centsToTransfer: UInt64

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Section {
            ForEach(exchanges) { exchange in
                ExchangeRowView(stack: stack.push(),
                             exchange: exchange,
//                               amount: amount,
                             currency: currency,            // TODO: (balance.available) amount.isZero to disable Deposit-button
                      centsToTransfer: $centsToTransfer)
            }
            .accessibilityElement(children: .combine)
        } header: {
            BarGraphHeader(stack: stack.push(), currency: currency)
        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct ExchangeRow_Container : View {
    @State private var centsToTransfer: UInt64 = 100

//    let amount = try! Amount(fromString: LONGCURRENCY + ":1234.56")
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
                            centsToTransfer: $centsToTransfer)
    }
}

fileprivate struct ExchangeSection_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ExchangeRow_Container()
        }
    }
}
#endif
