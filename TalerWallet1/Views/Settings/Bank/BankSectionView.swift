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

/// This view shows the currency name in an exchange section
///         currency
struct BankSectionView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let account: BankAccountsInfo

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("demoHints") var demoHints: Bool = true
    @AppStorage("fakeNoFees") var fakeNoFees: Bool = true
    @AppStorage("ownerName") var ownerName: String = EMPTYSTRING

    @State private var shouldReloadBalances: Int = 0
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var didDelete: Bool = false
    @State private var disabled: Bool = false
    @State private var showAlert: Bool = false
    @State private var purge: Bool = false
    @State private var global: Bool = false
    @State private var accountHolder: String = EMPTYSTRING
    @State private var iban: String = EMPTYSTRING
    @State private var xTaler: String = EMPTYSTRING
    @State private var label: String = EMPTYSTRING
    @State private var paytoType: PaytoType = .iban
    @State private var selected = 0
    @FocusState private var focus:FocusedField?

    enum FocusedField: Hashable {
        case accountHolder, iban, xTaler, label
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

    @MainActor
    private func deleteAccount() {
        disabled = true     // don't try this more than once
        Task { // runs on MainActor
//            if let _ = try? await model.deleteExchange(url: baseUrl, purge: purge, viewHandles: !purge) {
//                purge = false
//                symLog.log("deleted \(baseUrl.trimURL)")
//                didDelete = true             // change button text
//                NotificationCenter.default.post(name: .ExchangeDeleted, object: nil, userInfo: nil)
//                NotificationCenter.default.post(name: .BalanceChange, object: nil, userInfo: nil)
//                demoHints = true
//            } else {
//                purge = true
//                showAlert = true
//                disabled = false
//            }
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
        Section {
            NavigationLink {
                BankEditView(stack: stack.push(),
                           account: account)
            } label: {
                VStack(alignment: .leading) {
                    if let currencies = account.currencies {
                        if currencies.count == 1 {
                            BankSectionRow(title: String(localized: "Currency:"),
                                           value: currencies[0])
                        } else {
                            if !minimalistic { Text("Currencies:") }
                            ForEach (currencies, id: \.self) { currency in
                                Text(currency)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    } else {
                        BankSectionRow(title: String(localized: "Currency:"),
                                       value: "UNKNOWN")
                    }
                    BankSectionRow(title: String(localized: "Note:"),
                                   value: label)
                    BankSectionRow(title: String(localized: "Account holder:"),
                                   value: accountHolder)
                    BankSectionRow(title: String(localized: "\(methodType):", comment: "methodType:"),
                                   value: methodStr)
                    BankSectionRow(title: String(localized: "Status:"),
                                   value: kyc)
                }   .talerFont(.body)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Double tap to edit the account")
            }
        } header: {
        }
        .listRowSeparator(.hidden)
        .onChange(of: focus) {
            print($0)
        }
        .task { await viewDidLoad() }
//        .task(id: controller.currencyTicker) { await currencyTickerChanged(scopeInfo) }
        .onDisappear() {
            disabled = false
            purge = false
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
        } else if #available(iOS 16.0, *) {
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
