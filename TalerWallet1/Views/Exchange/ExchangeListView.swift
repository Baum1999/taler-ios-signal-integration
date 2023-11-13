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
    let stack: CallStack
    @Binding var balances: [Balance]
    let navTitle: String
#if TABBAR  // Taler Wallet
#else       // GNU Taler
    var hamburgerAction: () -> Void
#endif
    @EnvironmentObject private var model: WalletModel

    @State var showAlert: Bool = false
    @State var newExchange: String = TESTEXCHANGE

    func addExchange(_ exchange: String) -> Void {
        Task { // runs on MainActor
            symLog.log("adding: \(exchange)")
            do {
                try await model.addExchange(url: exchange)
                symLog.log("added: \(exchange)")
                announce(this: "added: \(exchange)")
            } catch {    // TODO: error handling - couldn't add exchangeURL
                symLog.log("error: \(error)")
            }
        }
    }

    var body: some View {
#if TABBAR  // Taler Wallet
        let hamburger: HamburgerButton? = nil
#else       // GNU Taler
        let hamburger = HamburgerButton(action: hamburgerAction)
#endif
        let accessibilityLabelStr = String(localized: "Add Exchange", comment: "accessibilityLabel for the + button")
        let plusButton = PlusButton(accessibilityLabelStr: accessibilityLabelStr) {
            showAlert = true
        }
        let addTitleStr = String(localized: "Add Exchange", comment: "title of the addExchange alert")
        let addButtonStr = String(localized: "Add", comment: "button in the addExchange alert")
        if #available(iOS 16.0, *) {
            ExchangeListCommonV(symLog: symLog, stack: stack.push(), balances: $balances)
                .navigationTitle(navTitle)
                .navigationBarItems(leading: hamburger, trailing: plusButton)
                .alert(addTitleStr, isPresented: $showAlert) {
                    TextField("Exchange address", text: $newExchange)
//                    .textFieldStyle(.roundedBorder)   Yikes: when adding style the alert will stop showing the textfield! Don't do this.
                    Button(addButtonStr) {
                        addExchange(newExchange)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Please enter the exchange URL")
                }
        } else {    // iOS 15 cannot have a textfield in an alert, so we must
            ExchangeListCommonV(symLog: symLog, stack: stack.push(), balances: $balances)
                .navigationTitle(navTitle)
                .navigationBarItems(leading: hamburger, trailing: plusButton)
                .textFieldAlert(isPresented: $showAlert,
                                      title: addTitleStr,
                                   doneText: addButtonStr,
                                       text: $newExchange) { text in
                    addExchange(text)
                }
        }
    }
}

struct ExchangeListCommonV: View {
    let symLog: SymLogV?
    let stack: CallStack
    @Binding var balances: [Balance]

    @EnvironmentObject private var model: WalletModel

    @State private var exchanges: [Exchange] = []

    // source of truth for the value the user enters in currencyField for exchange withdrawals
    @State private var amountToTransfer = Amount.zero(currency: "")     // TODO: Hold different values for different currencies?

    func reloadExchanges() async -> Void {
        exchanges = await model.listExchangesM()
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        //Text("Exchanges...")
        Content(symLog: symLog,
                 stack: stack.push(),
              balances: $balances,
             exchanges: $exchanges,
      amountToTransfer: $amountToTransfer,
       reloadExchanges: reloadExchanges)
        .overlay {
            if exchanges.isEmpty {
                Text("No Exchanges yet...")
                    .accessibilityFont(.body)
            }
        }
        .task {
            symLog?.log(".task")
            await reloadExchanges()
        }
    }
}
// MARK: -
extension ExchangeListCommonV {
    struct Content: View {
        let symLog: SymLogV?
        let stack: CallStack
        @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
        @Binding var balances: [Balance]
        @Binding var exchanges: [Exchange]
        @Binding var amountToTransfer: Amount           // does still have the wrong currency
        var reloadExchanges: () async -> Void

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
            // TODO: Balances for amountAvailable for Deposit
            let sortedDict = dict.sorted{ $0.key < $1.key}
            Group { // necessary for .backslide transition (bug in SwiftUI)
                List(sortedDict, id: \.key) { key, value in
                    ExchangeSectionView(stack: stack.push(),
                                     currency: key, exchanges: value,
                             amountToTransfer: $amountToTransfer)               // does still have the wrong currency
                }
                .refreshable {
                    symLog?.log("refreshing")
                    await reloadExchanges()
                }
                .listStyle(myListStyle.style).anyView
            }
            .onAppear() {
                DebugViewC.shared.setViewID(VIEW_EXCHANGES, stack: stack.push())
            }
            .onNotification(.ExchangeAdded) { notification in
                // doesn't need to be received on main thread because we just reload in the background anyway
                symLog?.log(".onNotification(.ExchangeAdded) ==> reloading exchanges")
                Task { await reloadExchanges() } // runs on MainActor
            }
        } // body
    }
}
