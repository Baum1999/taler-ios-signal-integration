/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

/// This view shows the list of exchanges
struct ExchangeListView: View {
    private let symLog = SymLogV(0)
    let navTitle: String
    var hamburgerAction: () -> Void

    @EnvironmentObject private var model: WalletModel

    @State private var exchanges: [Exchange] = []

    // source of truth for the value the user enters in currencyField for exchange withdrawals
    @State private var centsToTransfer: UInt64 = 0        // TODO: different values for different currencies?

    func reloadAction() async -> Void {
            exchanges = await model.listExchangesM()
    }

    func addExchange(_ exUrl: String) -> Void {
        Task {
            symLog.log("adding: \(exUrl)")
            do {
                try await model.addExchange(url: exUrl)
                symLog.log("added: \(exUrl)")
            } catch {    // TODO: error handling - couldn't add exchangeURL
                symLog.log("error: \(error)")
            }
        }
    }

    @State var showAlert: Bool = false
    @State var newExchange: String = TESTEXCHANGE

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let plusAction: () -> Void = {
//        withAnimation { showAlert = true }
            showAlert = true
        }

        //Text("Exchanges...")
        Content(symLog: symLog,
                exchanges: $exchanges,
                centsToTransfer: $centsToTransfer,
                reloadAction: reloadAction)
        .navigationTitle(navTitle)
        .navigationBarItems(leading: HamburgerButton(action: hamburgerAction),
                            trailing: PlusButton(action: plusAction)
                                        .accessibilityLabel("Add Exchange"))
        .overlay {
            if exchanges.isEmpty {
                Text("No Exchanges yet...")
                    .font(.talerBody)
            }
        }
        .task {
            symLog.log(".task")
            await reloadAction()
        }
        .textFieldAlert(isPresented: $showAlert, title: "Add Exchange",
                        doneText: "Add", text: $newExchange, action: addExchange)
    }
}
// MARK: -
//struct ExchangeAmount: Identifiable {
//    let exchange: Exchange
//    let amountAvailable: Amount
//
//    var id: String {    // needed for Identifiable
//        exchange.exchangeBaseUrl
//    }
//}
// MARK: -
extension ExchangeListView {
    struct Content: View {
        let symLog: SymLogV?
        @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
        @Binding var exchanges: [Exchange]
        @Binding var centsToTransfer: UInt64
        var reloadAction: () async -> Void

        func currenciesDict(_ exchanges: [Exchange]) -> [String : [Exchange]] {
            var currencies: [String : [Exchange]] = [:]

            for exchange in exchanges {
                let currency = exchange.currency ?? "Unknown"
                if currencies[currency] != nil {
                    currencies[currency]!.append(exchange)
                } else {
                    currencies[currency] = [exchange]
                }
            }
            return currencies
        }

//        @State private var exchangeAmount: ExchangeAmount? = nil

        var body: some View {
            let dict = currenciesDict(exchanges)
            let sortedDict = dict.sorted{ $0.key < $1.key}
            Group { // necessary for .backslide transition (bug in SwiftUI)
                List(sortedDict, id: \.key) { key, value in
                    ExchangeSectionView(currency: key, exchanges: value, centsToTransfer: $centsToTransfer)
                }
                .refreshable {
                    symLog?.log("refreshing")
                    await reloadAction()
                }
                .listStyle(myListStyle.style).anyView
            }
            .onAppear() {
                DebugViewC.shared.setViewID(VIEW_EXCHANGES)
            }
            .onNotification(.ExchangeAdded) { notification in
                // doesn't need to be received on main thread because we just reload in the background anyway
                symLog?.log(".onNotification(.ExchangeAdded) ==> reloading exchanges")
                Task { await reloadAction() }
            }
        } // body
    }
}
