/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

@MainActor
fileprivate
func addExchange(_ exchange: String, model: WalletModel) -> Void {
    Task { // runs on MainActor
        if let _ = try? await model.addExchange(uri: exchange) {
//            symLog.log("added: \(exchange)")
//            View.announce("added: \(exchange)")
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: "added: \(exchange)")
            }
            Controller.shared.hapticNotification(.success)
            NotificationCenter.default.post(name: .ExchangeAdded, object: nil, userInfo: nil)
            NotificationCenter.default.post(name: .BalanceChange, object: nil, userInfo: nil)       // TODO: ExchangeAdded should suffice
        }
    }
}

/// This view shows the list of exchanges
struct ExchangeListView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var url: URL?

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var showAlert: Bool = false
    @State private var newExchange: String = EXCHANGE + DEMO        // without HTTPS

    func checkExchanges() {
        var hasNoDEMO = true
        var hasNoTEST = true
        for balance in controller.balances {
            if let baseUrl = balance.scopeInfo.url {
                if baseUrl.contains(EXCHANGE + DEMO) {
                    hasNoDEMO = false
                } else if baseUrl.contains(EXCHANGE + TEST) {
                    hasNoTEST = false
                }
            }
        }
        newExchange = hasNoDEMO ? EXCHANGE + DEMO
                                : hasNoTEST && developerMode ? EXCHANGE + TEST
                                                             : EMPTYSTRING
    }

    var body: some View {
        let a11yLabelStr = String(localized: "Add payment service", comment: "a11y for the + button")
        let plusButton = PlusButton(accessibilityLabelStr: a11yLabelStr) {
            showAlert = true
        }
        let addTitleStr = String(localized: "Add payment service", comment: "title of the addExchange alert")
        let addButtonStr = String(localized: "Add", comment: "button in the addExchange alert")
        let enterURL = String(localized: "Enter the URL")
        let listView = ExchangeListCommonV(symLog: symLog, stack: stack.push(),
                                      newExchange:  $newExchange,
                                   checkExchanges: checkExchanges)
                        .navigationTitle(TITLE_EXCHANGES)
                        .navigationBarItems(trailing: plusButton)
                        .task {
                            if let newUrl = url {
                                newExchange = newUrl.trimmedString
                                showAlert = true
                                url = nil
                            } else {
                                checkExchanges()
                            }
                        }
        if #available(iOS 16.4, *) {
            listView.alert(addTitleStr, isPresented: $showAlert) {
                    TextField("Address of the payment service", text: $newExchange)
                        .accessibilityLabel(enterURL)
//                    .textFieldStyle(.roundedBorder)   Yikes: when adding style the alert will stop showing the textfield! Don't do this.
                    Button(addButtonStr) {
                        addExchange(newExchange, model: model)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            checkExchanges()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text(enterURL)
                        .accessibilityHidden(true)
                }
        } else {    // iOS 15 cannot have a textfield in an alert, so we must
            listView
                .textFieldAlert(isPresented: $showAlert,
                                      title: addTitleStr,
                                   doneText: addButtonStr,
                                       text: $newExchange) { text in
                    addExchange(text, model: model)
                }
        }
    }
}
// MARK: -
struct ExchangeListCommonV: View {
    let symLog: SymLogV?
    let stack: CallStack
    @Binding var newExchange: String
    let checkExchanges: () -> Void

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
#if DEBUG
        let excSection = Section {
            let cyclos = "https://guava.box.fdold.eu"
            Button(cyclos) {
                addExchange(cyclos, model: model)
            }

            let exchanges = ["glsint.fdold.eu", "taler.magnetbank.hu", "stage.taler-ops.ch", "e.netzbon-basel.ch"]
            ForEach(exchanges, id: \.self) { exchange in
                let urlStr = "exchange." + exchange
                Button(urlStr) {
                    addExchange(urlStr, model: model)
                }
//                Link(exchange, destination: URL(string: urlStr)!)
            }
        }
#endif
        let balanceList = List {
            ForEachWithIndex(data: controller.balances) { index, balance in
                ExchangeSectionView(stack: stack.push(),
                                  balance: balance,
                                 thousand: index * MAXEXCHANGES,        // unique ID
                            developerMode: developerMode) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        checkExchanges()
                    }
                }
            }
#if DEBUG
            if developerMode {
                excSection
            }
#endif
        }

        let emptyList = List {
            Section {
                Text("There are no payment services yet.")
                    .talerFont(.title3)
            }
            Section {
                let plus = Image(systemName: PLUS)
                if !minimalistic {
                    Text("Tap the \(plus) button to add a service.")
                        .listRowSeparator(.hidden)
                    Text("You can also scan a withdrawal QR code from your bank in the Action menu to automatically add a payment service.")
                } else {
                    Text("Tap \(plus) or scan a withdrawal QR code from your bank to add a payment service.")
                }
            }
                .talerFont(.body)
#if DEBUG
            if developerMode {
                excSection
            }
#endif
        }

        Group {
            if controller.balances.isEmpty {
                emptyList
            } else {
                balanceList                 // sorted by wallet-core
            }
        }
        .listStyle(myListStyle.style).anyView
//        .ignoresSafeArea(.keyboard, edges: .bottom)
        .refreshable {
            controller.hapticNotification(.success)
            symLog?.log("refreshing")
//            await reloadExchanges()
            NotificationCenter.default.post(name: .BalanceChange, object: nil, userInfo: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                checkExchanges()
            }
        }
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_PAYMENT_SERVICES, stack: stack.push())
        }
    } // body
}
