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
    var isLegacy: Bool

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var exchange: Exchange? = nil
    @State private var alertAccept: Bool = false
    @State private var alertDelete: Bool = false

    func notValid(_ amountString: String) -> String {
        String(localized: "Unfortunately this means, that your \(amountString) are not valid anymore, because they were obtained with the old security identity.")
    }

    func keep(_ amountString: String) -> String {
        String(localized: "Keep the \(amountString)")
    }

    func delete(_ amountString: String) -> String {
        String(localized: "Delete the \(amountString)")
    }

    func acceptAction() {
        if let exchange, let masterPub = exchange.masterPub {
            Task {
                try? await model.confirmExchangeKeyChange(exchangeBaseUrl: baseURL,
                                                         currentMasterPub: masterPub)
                dismiss()
            }
        } else {
            // TODO: Yikes!
        }
    }

    func deleteAction() {
        if let exchange, let masterPub = exchange.masterPub {
            Task {
                try? await model.purgeExchangeLegacyKeys(exchangeBaseUrl: baseURL,
                                                        currentMasterPub: masterPub)
                dismiss()
            }
        } else {
            // TODO: Yikes!
        }
    }

    func keepAction() {
        withAnimation {
            dismiss()
        }
    }

    private var acceptButton: some View {
        Button("Accept") {
            alertAccept = false
            acceptAction()
        }
    }
    private var deleteButton: some View {
        Button("Delete") {
            alertDelete = false
            deleteAction()
        }
    }
    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            alertAccept = false
            alertDelete = false
        }
    }

    @MainActor
    private func viewDidLoad() async {
        exchange = await controller.exchange(for: baseURL)
    }

    var body: some View {
        let scope = balance.scopeInfo
        let available = balance.available
        let formatted = available.formatted(scope, isNegative: false)
        let navTitle = String(localized: "Security Alert!", comment: "ViewTitle of UnconfirmedKeyChangeView")
        let warning1 = Text("Only trust the new identity if the payment service has confirmed this change.")
        let warning2 = Text("Otherwise, wait and try again later...")
        List {
            Section {
                Text("The security identity of \(baseURL.trimURL) has changed unexpectedly.")

                if isLegacy {
                    if !available.isZero {
                        let sorry = notValid(formatted.0)
                        let a11y = notValid(formatted.1)
                        Text(sorry)
                            .accessibilityLabel(a11y)
                        
                        warning1
                            .talerFont(.body)
                        warning2
                            .talerFont(.headline)

                        Button(keep(formatted.0), action: keepAction)
                            .buttonStyle(TalerButtonStyle(type: .bordered))
                            .padding(.horizontal)
                            .accessibilityLabel(keep(formatted.1))
                        
                        Text("If you are sure that the old security identity will not be used anymore, you can delete the invalid money.")
                            .talerFont(.body)
                        Button(delete(formatted.0), action: { alertDelete = true })
                            .buttonStyle(TalerButtonStyle(type: .bordered))
                            .padding(.horizontal)
                            .accessibilityLabel(delete(formatted.1))
                    }
                } else {
                    warning1
                    warning2
                        .bold()
                    Text("If you are sure that the old security identity will not be used anymore, you can withdraw new money with the new security identity.")
                    Button("Accept new security identity", action: { alertAccept = true })
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .padding(.horizontal)
                    Text("Money you obtained with the old security identity will be invalid.")
                }
            }
            .talerFont(.title2)
            .listRowSeparator(.hidden)
        }
        .listStyle(myListStyle.style).anyView
        .background(FullBackground())
        .navigationTitle(navTitle)
        .task {
            await viewDidLoad()
        }
        .alert("Accept the new payment service security identity.",
               isPresented: $alertAccept,
               actions: {   acceptButton
                            dismissAlertButton },
               message: {   Text("Are you sure? Your money obtained with the old security identity will be invalid.") })
        .alert("Delete money obtained with the old security identity.",
               isPresented: $alertDelete,
               actions: {   deleteButton
                            dismissAlertButton },
               message: {   Text("Are you sure? That money will be lost.") })
    }
}
// MARK: -
struct TransactionsEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsEmptyView(stack: CallStack("Preview"), currency: LONGCURRENCY)
    }
}
