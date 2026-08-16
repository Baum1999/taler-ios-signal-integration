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

/// This view shows the currency name in an exchange section
///         currency
struct BankSectionView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let account: BankAccountsInfo
    let selectedBalance: Balance?
    @Binding var amountLastUsed: Amount
    let goToEdit: Bool

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("ownerName") var ownerName: String = EMPTYSTRING

//    @State private var purge: Bool = false

    @State private var label: String = EMPTYSTRING
    @State private var accountHolder: String = EMPTYSTRING
    @State private var iban: String = EMPTYSTRING
    @State private var cyclos: String = EMPTYSTRING
    @State private var xTaler: String = EMPTYSTRING
    @State private var paytoType: PaytoType = .iban

//    @MainActor
//    private func validateIban() async {
//        if (try? await model.validateIban(iban)) == true {
//            let payto = "payto://iban/\(iban)?receiver-name=\(accountHolder)"
//            paytoUri = payto.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
//        } else {
//            paytoUri = nil
//        }
//    }

    @MainActor
    private func viewDidLoad() async {
        let payTo = PayTo(account.paytoUri)
        iban = payTo.iban ?? EMPTYSTRING
        cyclos = payTo.cyclos ?? EMPTYSTRING
        
        xTaler = payTo.xTaler ?? EMPTYSTRING
        if iban.isEmpty {
            if cyclos.count > 1 {
                paytoType = .cyclos
            } else if xTaler.count > 1 {
                paytoType = .xTalerBank
            } else {
                paytoType = .unknown
            }
        }
        label = account.label ?? EMPTYSTRING
        accountHolder = payTo.receiver ?? ownerName
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let kyc = account.kycCompleted ? String(localized: "verified")
                                       : String(localized: "not yet verified")
        let methodType = paytoType.rawValue.uppercased()
        let methodStr = (paytoType == .iban) ? iban
                    : (paytoType == .cyclos) ? cyclos
                : (paytoType == .xTalerBank) ? xTaler
                                             : "unknown payment method"
        let editHint = String(localized: "Double tap to edit the account", comment: "a11y")
        let selectHint = String(localized: "Double tap to select", comment: "a11y")
        Section {
            NavigationLink {
                if goToEdit {
                    BankEditView(stack: stack.push(),
                             accountID: account.bankAccountId)
                } else {
                    let navTitle = String(localized: "NavTitle_Deposit",    // _Currency",
                                       defaultValue: "Deposit")             // \(currencySymbol)"
                    DepositAmountAction(stack: stack.push(),
                              selectedBalance: selectedBalance,
                               amountLastUsed: $amountLastUsed,
                                     paytoUri: account.payToWorkAround,  // TODO:  paytoUri, after https://bugs.gnunet.org/view.php?id=11726 is fixed
                                        label: account.label)
                    .navigationTitle(navTitle)
                }
            } label: {
                VStack(alignment: .leading) {
                    if paytoType == .cyclos {
                        BankSectionRow(title: String(localized: "Cyclos user:"),
                                           value: accountHolder)
                    } else {
                        BankSectionRow(title: String(localized: "Account holder:"),
                                       value: accountHolder)
                        BankSectionRow(title: String(localized: "\(methodType):", comment: "methodType:"),
                                       value: methodStr)
                    }
                    BankSectionRow(title: String(localized: "Status:"),
                                   value: kyc)
                }   .talerFont(.body)
                    .listRowSeparator(.hidden)
//                    .accessibilityElement(children: .combine)
            }
            .accessibilityHint(goToEdit ? editHint : selectHint)
        } header: {
            Text(label)
                .talerFont(.title3)
//                .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
//                .accessibilityHint(EMPTYSTRING)
        }
        .task { await viewDidLoad() }
        .onDisappear() {
//            purge = false
        }
    }
}

struct BankSectionRow: View {
    let title: String
    let value: String

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        let hLayout = HStack {
            Text(title)
            Spacer()
            Text(value)
        }
        let vLayout = VStack(alignment: .leading) {
            Text(title)
            HStack {
                Spacer()
                Text(value)
            }
        }

        if minimalistic {
            Text(value)
        } else if #available(iOS 16.4, *) {
            ViewThatFits(in: .horizontal) {
                hLayout
                vLayout
            }.accessibilityElement(children: .combine)
        } else {
            vLayout
                .accessibilityElement(children: .combine)
        }

    }
}
