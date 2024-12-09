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

// Called when tapping [􁾩Deposit]
// user chooses a bank account
struct DepositSelectV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?
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
            Section {
                if bankAccounts.isEmpty {
                    let bankAccountsTitle = String(localized: "TitleBankAccounts", defaultValue: "Bank Accounts")
                    let bankAccountsDest = BankListView(stack: stack.push(bankAccountsTitle),
                                                        navTitle: bankAccountsTitle)
                    NavigationLink {        // whole row like in a tableView
                        bankAccountsDest
                    } label: {
                        SettingsItem(name: bankAccountsTitle, id1: "bankAccounts",
                              description: minimalistic ? nil : String(localized: "Your accounts for deposit...")) {}
                    }
                } else {
                    ForEach(bankAccounts, id: \.self) { account in
//                      let disabled = (accountHolder.count < 1) || paytoUri == nil    // TODO: check amountAvailable
                        let payURL = URL(string: account.paytoUri)
                        let iban = payURL?.iban
                        let xTaler = payURL?.xTaler
                        let alias = account.label
                        let kyc = account.kycCompleted ? String(localized: "verified", comment: "KYC state")
                                                       : String(localized: "not yet verified", comment: "KYC state")

                        let destination = DepositAmountV(stack: stack.push(),
                                               selectedBalance: $selectedBalance,
                                                amountLastUsed: $amountLastUsed,
                                                      paytoUri: account.paytoUri)
                        NavigationLink(destination: destination) {
                            VStack {
                                if let iban {
                                    Text("IBAN: \(iban)")
                                } else if let xTaler {
                                    Text("xTaler: \(xTaler)")
                                } else {
                                    Text("unknown payment method")
                                }
                                Text("Status: \(kyc)")
                                    .padding(.leading)
                                if let alias {
                                    Text(alias)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(myListStyle.style).anyView
        .refreshable {
            controller.hapticNotification(.success)
            symLog.log("refreshing")
            await viewDidLoad()
        }
        .task { await viewDidLoad() }
        .navigationTitle(subjectTitle)
//        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_DEPOSIT_ACCEPT, stack: stack.push())
//            print("❗️ P2PSubjectV onAppear")
        }
        .onDisappear {
//            print("❗️ P2PSubjectV onDisappear")
        }
//        .task(id: depositIBAN) { await validateIban() }
    }
}
// MARK: -
#if DEBUG
#endif
