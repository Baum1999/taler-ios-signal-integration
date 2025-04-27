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
    @State private var xTaler: String = EMPTYSTRING
    @State private var paytoType: PaytoType = .iban
    @State private var selected = 0

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
        let payURL = URL(string: account.paytoUri)
        iban = payURL?.iban ?? EMPTYSTRING
        xTaler = payURL?.xTaler ?? EMPTYSTRING
        label = account.label ?? EMPTYSTRING
        if let queryParameters = payURL?.queryParameters {
            let name = if let rcv = queryParameters["receiver-name"] {
                rcv.replacingOccurrences(of: "+", with: SPACE)
            } else {
                ownerName
            }
            accountHolder = name
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let kyc = account.kycCompleted ? String(localized: "verified")
                                       : String(localized: "not yet verified")
        let methods = [PaytoType.iban, PaytoType.xTalerBank]
        let methodType = methods[selected].rawValue.uppercased()
        let methodStr = (paytoType == .iban) ? iban
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
                    DepositAmountV(stack: stack.push(),
                         selectedBalance: selectedBalance,
                          amountLastUsed: $amountLastUsed,
                                paytoUri: account.paytoUri,
                                   label: account.label)
                    .navigationTitle(navTitle)
                }
            } label: {
                VStack(alignment: .leading) {
                    BankSectionRow(title: String(localized: "Account holder:"),
                                   value: accountHolder)
                    BankSectionRow(title: String(localized: "\(methodType):", comment: "methodType:"),
                                   value: methodStr)
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
