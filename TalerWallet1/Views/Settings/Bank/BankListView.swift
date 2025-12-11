/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

/// This view shows the list of exchanges
struct BankListView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)      // needed for Deposit, ignore
    @State private var showAddDialog: Bool = false
    @State private var bankAccounts: [BankAccountsInfo] = []

    @MainActor
    func addExchange(_ exchange: String) -> Void {
        Task { // runs on MainActor
            symLog.log("adding: \(exchange)")
            if let _ = try? await model.addExchange(uri: exchange) {
                symLog.log("added: \(exchange)")
                announce("added: \(exchange)")
                NotificationCenter.default.post(name: .ExchangeAdded, object: nil, userInfo: nil)
            }
        }
    }

    @MainActor
    private func viewDidLoad() async {
        if let accounts = try? await model.listBankAccounts() {
            withAnimation { bankAccounts = accounts }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let a11yLabelStr = String(localized: "Add bank account", comment: "a11y for the + button")
        let plusButton = PlusButton(accessibilityLabelStr: a11yLabelStr) {
            showAddDialog = true
        }
        let addTitleStr = String(localized: "Add bank account", comment: "title of the addExchange alert")
        let addButtonStr = String(localized: "Add", comment: "button in the addExchange alert")

        let depositHint = Text("You can only deposit to a bank account that you control, otherwise you will not be able to fulfill the regulatory requirements.")

        let emptyList = Group {
            Section {
                Text("There are no bank accounts yet.")
                    .talerFont(.title3)
            }
            Section {
                depositHint
                let plus = Image(systemName: "plus")
                if !minimalistic {
                    Text("Tap the \(plus) button to add an account.")
                        .listRowSeparator(.hidden)
                    Text("You can also scan a withdrawal QR code from your bank in the Action menu to automatically add a bank account.")
                } else {
                    Text("Tap \(plus) or scan a withdrawal QR code from your bank to add a bank account.")
                }
            }
                .talerFont(.body)
        }

        let addBankDest = BankEditView(stack: stack.push(), accountID: nil)
        let actions = Group {
            NavLink($showAddDialog) { addBankDest }
        }

        List {
            if bankAccounts.isEmpty {
                emptyList
//                    .opacity(0)           // TODO: wait 0.5 seconds, then fade in
            } else {
                depositHint
                ForEach(bankAccounts, id: \.self) { account in
                    BankSectionView(stack: stack.push(),
                                  account: account,
                          selectedBalance: nil,                                 // needed for Deposit, ignore
                           amountLastUsed: $amountLastUsed,                     // needed for Deposit, ignore
                                 goToEdit: true)
                }
            }
        }
        .background(actions)
        .listStyle(myListStyle.style).anyView
        .refreshable {
            controller.hapticNotification(.success)
            symLog.log("refreshing")
            await viewDidLoad()
        }
        .onNotification(.BankAccountChange) { notification in
//            logger.info(".onNotification(.BankAccountChange) ==> reload accounts")
            Task { await viewDidLoad() }
        }
        .task { await viewDidLoad() }
        .navigationTitle(navTitle)
        .navigationBarItems(trailing: plusButton)
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_BANK_ACCOUNTS, stack: stack.push())
        }
    } // body
}
