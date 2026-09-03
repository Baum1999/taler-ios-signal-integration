/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

/// This view shows hints if a wallet is empty
/// It is the very first thing the user sees after installing the app

struct TransactionsEmptyView: View {
    let stack: CallStack
    let currency: String

    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    var body: some View {
        List {
            Section {
                Text("There are no transactions for \(currency).")
            }
            .talerFont(.title2)
        }
        .listStyle(myListStyle.style).anyView
        .background(FullBackground())
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_EMPTY_HISTORY, stack: stack.push())     // 20
        }
    }
}

// MARK: -
struct UnconfirmedKeyChangeView: View {
    var baseURL: String
    var balance: Balance

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var exchange: Exchange? = nil

    func notValid(_ amountString: String) -> String {
        String(localized: "Unfortunately this means, that your \(amountString) are not valid anymore, because they were obtained with the old public key.")
    }

    func keep(_ amountString: String) -> String {
        String(localized: "Keep the \(amountString)")
    }

    func delete(_ amountString: String) -> String {
        String(localized: "Delete the \(amountString)")
    }

    func confirmExchangeKeyChange() {
        if let exchange, let masterPub = exchange.masterPub {
            Task {
                try? await model.confirmExchangeKeyChange(exchangeBaseUrl: baseURL,
                                                         currentMasterPub: masterPub)
                dismiss()
            }
        }
    }

    func purgeExchangeLegacyKeys() {
        if let exchange, let masterPub = exchange.masterPub {
            Task {
                try? await model.purgeExchangeLegacyKeys(exchangeBaseUrl: baseURL,
                                                        currentMasterPub: masterPub)
                dismiss()
            }
        }
    }

    func keepAction() {
        withAnimation {

        }
        confirmExchangeKeyChange()
    }

    func deleteAction() {
        withAnimation {
        }
        confirmExchangeKeyChange()
        purgeExchangeLegacyKeys()
    }

    @MainActor
    private func viewDidLoad() async {
        exchange = await controller.exchange(for: baseURL)
    }

    var body: some View {
        let available = balance.available
        let navTitle = String(localized: "Public key changed", comment: "ViewTitle of UnconfirmedKeyChangeView")
        List {
            Section {
                Text("The exchange \(baseURL.trimURL) has got a new public key.")

                if !available.isZero {
                    let scope = balance.scopeInfo
                    let formatted = available.formatted(scope, isNegative: false)
                    let sorry = notValid(formatted.0)
                    let a11y = notValid(formatted.1)
                    Text(sorry)
                        .accessibilityLabel(a11y)

                    Text("Maybe the exchange has just a configuration problem, and the old public key will be reinstated.")
                        .talerFont(.body)
                    Button(keep(formatted.0), action: keepAction)
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .padding(.horizontal)
                        .accessibilityLabel(keep(formatted.1))

                    Text("If you are sure that the old public key will not be used anymore, you can delete the invalid money.")
                        .talerFont(.body)
                    Button(delete(formatted.0), action: deleteAction)
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .padding(.horizontal)
                        .accessibilityLabel(delete(formatted.1))
                }
            }
            .talerFont(.title2)
            .listRowSeparator(.hidden)
        }
        .listStyle(myListStyle.style).anyView
        .background(FullBackground())
        .navigationTitle(navTitle)
    }
}
// MARK: -
struct TransactionsEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsEmptyView(stack: CallStack("Preview"), currency: LONGCURRENCY)
    }
}
