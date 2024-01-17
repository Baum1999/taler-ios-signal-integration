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
    @AppStorage("iconOnly") var iconOnly: Bool = false

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Section {
            ForEach(exchanges) { exchange in
                ExchangeRowView(stack: stack.push(),
                             exchange: exchange,
                             currency: currency,            // TODO: (balance.available) amount.isZero to disable Deposit-button
                     amountToTransfer: $amountToTransfer)   // does still have the wrong currency
                .listRowSeparator(.hidden)
            }
            if "KUDOS" == currency {
                let bankingHint = String(localized: "Since the demo bank supports the Taler integration, you can start a withdrawal directly on the")
                let linkTitle = String(localized: "LinkTitle_DEMOBANK", defaultValue: "Demo Bank Website")
                VStack {
                    if !iconOnly {
                        Text(bankingHint)
                    }
                    Link(linkTitle, destination: URL(string: DEMOBANK)!)
                        .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(bankingHint + " " + linkTitle)
                .padding(.top)
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
