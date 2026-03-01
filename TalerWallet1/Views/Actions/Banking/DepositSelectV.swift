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

// Called when tapping [􁾩Deposit]
// user chooses a bank account
struct DepositSelectV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    // when Action is tapped while in currency TransactionList…
    let selectedBalance: Balance?   // …then use THIS balance, otherwise show picker
    @Binding var amountLastUsed: Amount

//    let amountAvailable: Amount?
//    @Binding var depositIBAN: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("depositIBAN") var depositIBAN: String = EMPTYSTRING
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var myFeeLabel: String = EMPTYSTRING
    @State private var transactionStarted: Bool = false
    @FocusState private var isFocused: Bool
    @State private var currencyName: String = UNKNOWN
    @State private var currencySymbol: String = UNKNOWN
    @State private var amountAvailable = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var bankAccounts: [BankAccountsInfo] = []


    private var subjectTitle: String {
        return String(localized: "NavTitle_Deposit_Select",
                   defaultValue: "Select account",
                        comment: "NavTitle: Deposit")
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
        let _ = symLog.vlog(amountToTransfer.readableDescription)       // just to get the #
#endif
        let depositHint = Text("You can only deposit to a bank account that you control, otherwise you will not be able to fulfill the regulatory requirements.")

        List {
            Section {
                depositHint
            }
            if bankAccounts.isEmpty {
                Section {
                    let bankAccountsTitle = String(localized: "TitleBankAccounts", defaultValue: "Bank Accounts")
                    let bankAccountsDest = BankListView(stack: stack.push(bankAccountsTitle),
                                                        navTitle: bankAccountsTitle)
                    NavigationLink {        // whole row like in a tableView
                        bankAccountsDest
                    } label: {
                        SettingsItem(name: bankAccountsTitle, id1: "bankAccounts",
                              description: String(localized: "Your accounts for deposit...")) {}
                    }
                }
            } else {
                ForEach(bankAccounts, id: \.self) { account in
//                  let disabled = (accountHolder.count < 1) || paytoUri == nil    // TODO: check amountAvailable
                    BankSectionView(stack: stack.push(),
                                  account: account,
                          selectedBalance: selectedBalance,
                           amountLastUsed: $amountLastUsed,
                                 goToEdit: false)
                }
            }
        }
        .listStyle(myListStyle.style).anyView
        .refreshable {
            controller.hapticNotification(.success)
            symLog.log("refreshing")
            await viewDidLoad()
        }
        .task { 
            setVoice(to: nil)
            await viewDidLoad()
        }
        .navigationTitle(subjectTitle)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_DEPOSIT_ACCEPT, stack: stack.push())
//            symLog.log("❗️ DepositSelectV onAppear")
        }
        .onDisappear {
//            symLog.log("❗️ DepositSelectV onDisappear")
        }
//        .task(id: depositIBAN) { await validateIban() }
    }
}
// MARK: -
#if DEBUG
#endif
