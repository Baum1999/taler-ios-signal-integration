/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
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
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller

    @State var showAlert: Bool = false
    @State var newExchange: String = TESTEXCHANGE

    func addExchange(_ exchange: String) -> Void {
        Task { // runs on MainActor
            symLog.log("adding: \(exchange)")
            if let _ = try? await model.addExchange(url: exchange) {
                symLog.log("added: \(exchange)")
                announce(this: "added: \(exchange)")
            }
        }
    }

    var body: some View {
        let accessibilityLabelStr = String(localized: "Add Payment Service", comment: "accessibilityLabel for the + button")
        let plusButton = PlusButton(accessibilityLabelStr: accessibilityLabelStr) {
            showAlert = true
        }
        let addTitleStr = String(localized: "Add Payment Service", comment: "title of the addExchange alert")
        let addButtonStr = String(localized: "Add", comment: "button in the addExchange alert")
        if #available(iOS 16.0, *) {
            ExchangeListCommonV(symLog: symLog, stack: stack.push(), balances: $balances)
                .navigationTitle(navTitle)
                .navigationBarItems(trailing: plusButton)
                .alert(addTitleStr, isPresented: $showAlert) {
                    TextField("Address of Payment Service", text: $newExchange)
//                    .textFieldStyle(.roundedBorder)   Yikes: when adding style the alert will stop showing the textfield! Don't do this.
                    Button(addButtonStr) {
                        addExchange(newExchange)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Please enter the URL")
                }
        } else {    // iOS 15 cannot have a textfield in an alert, so we must
            ExchangeListCommonV(symLog: symLog, stack: stack.push(), balances: $balances)
                .navigationTitle(navTitle)
                .navigationBarItems(trailing: plusButton)
                .textFieldAlert(isPresented: $showAlert,
                                      title: addTitleStr,
                                   doneText: addButtonStr,
                                       text: $newExchange) { text in
                    addExchange(text)
                }
        }
    }
}
// MARK: -
struct ExchangeListCommonV {
    let symLog: SymLogV?
    let stack: CallStack
    @Binding var balances: [Balance]

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
//    @AppStorage("depositIBAN") var depositIBAN = EMPTYSTRING
//    @AppStorage("accountHolder") var accountHolder = EMPTYSTRING

    @State private var exchanges: [Exchange] = []

    // source of truth for the value the user enters in currencyField for exchange withdrawals
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)     // TODO: Hold different values for different currencies?

    func reloadExchanges() async -> Void {
        if let exc = try? await model.listExchangesM() {
            exchanges = exc
        }
    }
}
// MARK: -
extension ExchangeListCommonV: View {
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let sortedExchanges = exchanges.sorted { $0 < $1 }
        // TODO: Balances for amountAvailable for Deposit
        Group {
            List(sortedExchanges, id: \.self) { exchange in
                ExchangeSectionView(stack: stack.push(),
                                 balances: $balances,
                                 exchange: exchange,
//                              depositIBAN: $depositIBAN,
//                            accountHolder: $accountHolder,
                         amountToTransfer: $amountToTransfer)               // does still have the wrong currency
            }
            .refreshable {
                symLog?.log("refreshing")
                await reloadExchanges()
            }
            .listStyle(myListStyle.style).anyView
        }
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_BANKING, stack: stack.push())
        }
        .overlay {
            if exchanges.isEmpty {
                List {
                    Section {
                        Text("There are no Payment Services yet.")
                            .talerFont(.title3)
                    }
                    Section {
                        Text("Use the Add button to add a service.")
                            .talerFont(.body)
                            .listRowSeparator(.hidden)
                        Text("You can also scan a withdrawal QR code from your bank on the Balances tab to automatically add a payment service.")
                            .talerFont(.body)
                    }
                }
                .refreshable {
                    symLog?.log("refreshing")
                    await reloadExchanges()
                }
                .listStyle(myListStyle.style).anyView
            }
        }
        .onNotification(.ExchangeAdded) { notification in
            // doesn't need to be received on main thread because we just reload in the background anyway
            symLog?.log(".onNotification(.ExchangeAdded) ==> reloading exchanges")
            Task { await reloadExchanges() } // runs on MainActor
        }
        .task {
            symLog?.log(".task")
            await reloadExchanges()
        }
    } // body
}
