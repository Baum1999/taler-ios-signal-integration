/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct ExchangeRowView: View {
    let exchange: Exchange
    let currency: String
    @Binding var centsToTransfer: UInt64

    @State private var buttonSelected: Int? = nil
    var body: some View {
        let baseURL = exchange.exchangeBaseUrl

        HStack(spacing: 0) {    // can't use the built in Label because it adds the accessory arrow
            Text(baseURL.trimURL())

            NavigationLink(destination: LazyView {
                EmptyView()     // TODO: Deposit
            }, tag: 1, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0)
            NavigationLink(destination: LazyView {
                ManualWithdraw(exchange: exchange,
                               centsToTransfer: $centsToTransfer)
            }, tag: 2, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0)
        }.listRowSeparator(.hidden)

        HStack {        // buttons just set "buttonSelected" so the NavigationLink will trigger
            Button("Deposit\n\(currency)") { buttonSelected = 1 }
                .multilineTextAlignment(.center)
                .buttonStyle(TalerButtonStyle(type: .bordered))
                .disabled(true)     // TODO: after implementing Deposit check available

            Button("Withdraw\n\(currency)") { buttonSelected = 2 }
                .multilineTextAlignment(.center)
                .buttonStyle(TalerButtonStyle(type: .bordered))
        }.listRowSeparator(.visible)
//        .listRowSeparatorTint(.red)
        .fixedSize(horizontal: false, vertical: true)
    }
}
/// This view shows the currency name in an exchange section
///         currency
/// [Deposit Coins]  [Withdraw Coins]
struct ExchangeSectionView: View {
    let currency: String
    let exchanges: [Exchange]

    @Binding var centsToTransfer: UInt64

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Section {
            ForEach(exchanges) { exchange in
                ExchangeRowView(exchange: exchange, currency: currency, centsToTransfer: $centsToTransfer)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text(currency)
                .font(.title)
        }
    }
}
// MARK: -
#if DEBUG
struct ExchangeRow_Container : View {
    @State private var centsToTransfer: UInt64 = 100

    var body: some View {
        let exchange1 = Exchange(exchangeBaseUrl: DEMO_AGE_EXCHANGE,
                                        currency: LONGCURRENCY,
                                       paytoUris: [],
                                       tosStatus: "tosStatus",
                                  exchangeStatus: "exchangeStatus",
                           ageRestrictionOptions: [12,16],
                                       permanent: true)
        let exchange2 = Exchange(exchangeBaseUrl: DEMO_EXP_EXCHANGE,
                                        currency: LONGCURRENCY,
                                       paytoUris: [],
                                       tosStatus: "tosStatus",
                                  exchangeStatus: "exchangeStatus",
                           ageRestrictionOptions: [],
                                       permanent: false)
        List {
            ExchangeSectionView(currency: LONGCURRENCY, exchanges: [exchange1, exchange2],
                                centsToTransfer: $centsToTransfer)
        }
    }
}

struct ExchangeRow_Previews: PreviewProvider {
    static var previews: some View {
        ExchangeRow_Container()
    }
}
#endif
