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

/// This view shows the currency name in an exchange section
///         currency
struct BankEditView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let accountID: String?

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("demoHints") var demoHints: Bool = true
//    @AppStorage("fakeNoFees") var fakeNoFees: Bool = true     TODO: use this flag!
    @AppStorage("ownerName") var ownerName: String = EMPTYSTRING

    @State private var shouldReloadBalances: Int = 0
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var didDelete: Bool = false
    @State private var disabled: Bool = false
    @State private var showAlert: Bool = false

    @State private var myAccount: String? = nil
    @State private var accountHolder: String = EMPTYSTRING
    @State private var iban: String = EMPTYSTRING
    @State private var ibanValid = false
    @State private var xTaler: String = EMPTYSTRING
    @State private var accountLabel: String = EMPTYSTRING
    @State private var paytoType: PaytoType = .iban
    @State private var selected = 0
    @State private var kycCompleted = false
    @State private var finished = false
    @State private var unchanged = true
    @State private var userTyped = false

    @FocusState private var focus:FocusedField?

    enum FocusedField: Hashable {
        case accountLabel, accountHolder, iban, xTaler
    }

//    @MainActor
//    private func validateIban() async {
//        if (try? await model.validateIban(iban)) == true {
//            let payto = "payto://iban/\(iban)?receiver-name=\(accountHolder)"
//            paytoUri = payto.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
//        } else {
//            paytoUri = nil
//        }
//    }

    @ViewBuilder func barButton() -> some View {
        let isNew = accountID == nil
        let titleStr = isNew ? String(localized: "Add", comment: "button title: Add bank account")
                             : String(localized: "Update", comment: "button title: Update bank account")
        let a11yStr = isNew ? String(localized: "Add bank account", comment: "a11y")
                            : String(localized: "Update bank account", comment: "a11y")
        let notValid: Bool = paytoType == .iban ? (iban.isEmpty || !ibanValid)
                                                : xTaler.isEmpty
        DoneButton(titleStr: titleStr, accessibilityLabelStr: titleStr) {
            Task {
                if await updateAccount() {
                    dismiss()
                }
            }
        }
            .disabled(disabled || notValid || unchanged)
    }

    @MainActor
    private func viewDidLoad() async {
        if let accountID {
            if let account = try? await model.getBankAccountById(accountID) {
                accountLabel = account.label ?? EMPTYSTRING
                kycCompleted = account.kycCompleted
                let payTo = PayTo(account.paytoUri)
                accountHolder = payTo.receiver ?? ownerName
                xTaler = payTo.xTaler ?? EMPTYSTRING
                iban = payTo.iban ?? EMPTYSTRING
                if iban.isEmpty {
                    if xTaler.count > 1 {
                        paytoType = .xTalerBank
                    }
                } else if let result = try? await model.validateIban(iban) {
                    ibanValid = result
                }
            }
        } else {

        }
    }

    @MainActor
    private func updateAccount() async -> Bool {
        let isIBAN = paytoType == .iban
        if !accountHolder.isEmpty && !accountLabel.isEmpty {
            if isIBAN ? !iban.isEmpty
                      : !xTaler.isEmpty {
                let payto = isIBAN ? "payto://iban/\(iban)?receiver-name=\(accountHolder)"       // TODO: convert BBAN to IBAN
                                   : "payto://xTaler/\(xTaler)?receiver-name=\(accountHolder)"
                let paytoUri = payto.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                symLog.log(paytoUri)
                if let account = try? await model.addBankAccount(paytoUri,
                                                           label: accountLabel,
                                                         replace: myAccount ?? accountID
                ) {
                    symLog.log(account)
                    myAccount = account
                    return true
                } else {
                    symLog.log("error addBankAccount")
                }
            }
        }
        return false
    }

    @MainActor
    private func deleteAccount() {
        disabled = true     // don't try this more than once
        Task { // runs on MainActor
            if let id = myAccount ?? accountID {
                if let _ = try? await model.forgetBankAccount(id) {
                    symLog.log("forgot \(id)")
                    didDelete = true             // change button text
//                NotificationCenter.default.post(name: .ExchangeDeleted, object: nil, userInfo: nil)
//                NotificationCenter.default.post(name: .BalanceChange, object: nil, userInfo: nil)
                    dismissTop(stack.push())
                } else {
                    showAlert = true
                    disabled = false
                }
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif

        let methods = [PaytoType.iban, PaytoType.xTalerBank]
        List {
            if kycCompleted // || true
            {   Section {
                    Text("If you change the account holder name or the IBAN, you may have to perform the legitimization procedure again.")          // TODO: BBAN
                        .talerFont(.body)
                }
            }
            Section {
                let labelTitle = String(localized: "Label")
                let labelColon = String("\(labelTitle):")
                if !minimalistic {
                    Text(labelColon)
                        .talerFont(.picker)
                        .accessibilityHidden(true)
                        .padding(.bottom, -12)
                }
                TextField(minimalistic ? labelTitle : EMPTYSTRING, text: $accountLabel)
                    .accessibilityLabel(labelColon)
                    .focused($focus, equals: .accountLabel)
                    .talerFont(.title3)
                    .foregroundColor(WalletColors().fieldForeground)     // text color
                    .background(WalletColors().fieldBackground)
                    .textFieldStyle(.roundedBorder)
                    .padding(.bottom)
                    .onChange(of: accountLabel) { newValue in
                        if userTyped {
                            unchanged = false
                        }
                    }

                let holderTitle = String(localized: "Account holder")
                let holderColon = String("\(holderTitle):")
                if !minimalistic {
                    Text(holderColon)
                        .talerFont(.picker)
                        .accessibilityHidden(true)
                        .padding(.bottom, -12)
                }
                TextField(minimalistic ? holderTitle : EMPTYSTRING, text: $accountHolder)
                    .accessibilityLabel(holderColon)
                    .focused($focus, equals: .accountHolder)
                    .talerFont(.title3)
                    .foregroundColor(WalletColors().fieldForeground)     // text color
                    .background(WalletColors().fieldBackground)
                    .textFieldStyle(.roundedBorder)
                    .padding(.bottom)
                    .onChange(of: accountHolder) { newValue in
                        if userTyped {
                            unchanged = false
                        }
                    }

                let paytoStr = paytoType.rawValue.uppercased()
                let paytoColon = String("\(paytoStr):")
                if let accountID {
                    // we are editing an existing bank account
                    Text(paytoColon)
                        .talerFont(.picker)
                        .accessibilityHidden(true)
                        .padding(.bottom, -12)
                } else {
                    // this is a NEW bank account - choose a payment method
                    Picker(EMPTYSTRING, selection: $selected) {
                        ForEach(0..<methods.count, id: \.self) { index in
                            let method = methods[index]
                            Text(method.rawValue.uppercased())
                                .tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selected) { newValue in
                        paytoType = methods[newValue]
                    }
                }
                if paytoType == .iban {
                    TextField(paytoStr, text: $iban)            // TODO: BBAN
                        .accessibilityLabel(paytoColon)
                        .focused($focus, equals: .iban)
                        .talerFont(.title3)
                        .foregroundColor(WalletColors().fieldForeground)     // text color
                        .background(WalletColors().fieldBackground)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom)
                        .onChange(of: iban) { newValue in
                            Task {
                                if let result = try? await model.validateIban(newValue) {
                                    ibanValid = result
                                }
                            }
                        }
                } else if paytoType == .xTalerBank {
                    TextField(paytoStr, text: $xTaler)
                        .accessibilityLabel(paytoColon)
                        .focused($focus, equals: .xTaler)
                        .talerFont(.title3)
                        .foregroundColor(WalletColors().fieldForeground)     // text color
                        .background(WalletColors().fieldBackground)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom)
                        .onChange(of: xTaler) { newValue in
                            if userTyped {
                                unchanged = false
                            }
                        }
                } else {
                    Text("unknown payment method")
                        .talerFont(.title3)
                        .padding(.bottom)
                }

                if let accountID {
                    let buttonTitle = String(localized: "Account.Delete", defaultValue: "Forget bank account", comment: "Action button")
                    let warningText1 = String(localized: "Are you sure you want to forget this bank account?")
                    WarningButton(warningText: warningText1,
                                  buttonTitle: buttonTitle,
                                   buttonIcon: "trash",
                                         role: .destructive,                            // TODO: WalletColors().errorColor
                                     disabled: $disabled,
                                       action: deleteAccount)
                        .padding(.top)
                }
            }.listRowSeparator(.hidden)
        } // List
        .navigationBarItems(trailing: barButton())
//        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: focus) { [focus] newState in
            switch newState {
                case .none:
                    break
                case .some(_):
                    userTyped = true
            }
        }
        .task { await viewDidLoad() }
        .onDisappear() {
            disabled = false
        }
    }
}
