/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

/// This view shows the list of exchanges
struct ExchangeListView: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Exchanges")

    @ObservedObject var model: ExchangeModel
    var hamburgerAction: () -> Void


    // source of truth for the value the user enters in currencyField
    @State private var centsToTransfer: UInt64 = 0        // TODO: different values for different currencies

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let reloadAction = model.updateListM
        Content(symLog: symLog, model: model,
                centsToTransfer: $centsToTransfer,
                reloadAction: reloadAction)
            .navigationBarItems(leading: HamburgerButton(action: hamburgerAction))
            .navigationTitle(navTitle)
            .task {
                symLog.log(".task")
                do {
                    try await reloadAction()
                } catch {    // TODO: show error
                    symLog.log(error.localizedDescription)
                }
            }
    }
}
// MARK: -
struct ExchangeAmount: Identifiable {
    let exchange: Exchange
    let amountAvailable: Amount

    var id: String {    // needed for Identifiable
        exchange.exchangeBaseUrl
    }
}
// MARK: -
extension ExchangeListView {
    struct Content: View {
        let symLog: SymLogV?
        @AppStorage("listStyle") var myListStyle = MyListStyle.automatic
        @ObservedObject var model: ExchangeModel
        @Binding var centsToTransfer: UInt64
        var reloadAction: () async throws -> ()

        @State var showAlert: Bool = false
        @State var newExchange: String = "https://exchange-age.taler.ar/"

        func addExchange(_ exUrl: String) -> Void {
            Task {
                do {
                    symLog?.log("adding: \(exUrl)")
                    try await model.add(url: exUrl)
                    symLog?.log("added: \(exUrl)")
                } catch {    // TODO: error handling - couldn't add exchangeURL
                    symLog?.log("error: \(error)")
                }
            }
        }

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

        @State private var exchangeAmount: ExchangeAmount? = nil

        var body: some View {
            let plusAction: () -> Void = {
//                withAnimation { showAlert = true }
                showAlert = true
            }
            VStack {
                if model.exchanges.isEmpty {
                    Text("No Exchanges yet...")
                } else {
                    ScrollViewReader { scrollView in    // 
                        let dict = currenciesDict(model.exchanges)
                        let sortedDict = dict.sorted{ $0.key < $1.key}
                        List {
                            ForEach(sortedDict, id: \.key) { key, value in
                                ExchangeSectionView(currency: key, exchanges: value, centsToTransfer: $centsToTransfer)
                            }
                        }
                        .refreshable {
                            do {
                                symLog?.log("refreshing")
                                try await reloadAction()
                            } catch {    // TODO: error
                                symLog?.log(error.localizedDescription)
                            }
                        }
                        .listStyle(myListStyle.style)
                        .anyView
                    }
                } // else
            }.onAppear() {
                DebugViewC.shared.setViewID(VIEW_EXCHANGES)
            }
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(trailing: PlusButton(action: plusAction))
            .textFieldAlert(isPresented: $showAlert, title: "Add Exchange",
                               doneText: "Add", text: $newExchange, action: addExchange)
        } // body
    }
}
