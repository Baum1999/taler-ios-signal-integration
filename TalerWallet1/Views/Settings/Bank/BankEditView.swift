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
struct BankEditView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let accountID: String?

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
//    @State private var global: Bool = false
    @State private var accountHolder: String = EMPTYSTRING
    @State private var iban: String = EMPTYSTRING
    @State private var xTaler: String = EMPTYSTRING
    @State private var label: String = EMPTYSTRING
    @State private var paytoType: PaytoType = .iban
    @State private var currencies: [String] = []
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
        if let accountID {
            if let account = try? await model.getBankAccountById(accountID) {
                let payURL = URL(string: account.paytoUri)
                iban = payURL?.iban ?? EMPTYSTRING
                xTaler = payURL?.xTaler ?? EMPTYSTRING
                label = account.label ?? EMPTYSTRING
                if let queryParameters = payURL?.queryParameters {
                    let name = queryParameters["receiver-name"] ?? ownerName
                    accountHolder = name.replacingOccurrences(of: "+", with: SPACE)
                }
                currencies = account.currencies ?? []
            }
        } else {

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
        let methods = [PaytoType.iban, PaytoType.xTalerBank]
        List { Group {
            let accountTitle = String(localized: "Account holder")
            let accountColon = String("\(accountTitle):")
            if !minimalistic {
                Text(accountColon)
                    .talerFont(.body)
                    .accessibilityHidden(true)
            }
            TextField(minimalistic ? accountTitle : EMPTYSTRING, text: $accountHolder)
                .accessibilityLabel(accountColon)
                .focused($focus, equals: .accountHolder)
                .talerFont(.title3)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)
                .padding(.top, -4)
                .padding(.bottom)

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

            Group {
                let paytoStr = paytoType.rawValue.uppercased()
                let paytoColon = String("\(paytoStr):")
                if paytoType == .iban {
                    TextField(paytoStr, text: $iban)
                        .accessibilityLabel(paytoColon)
                        .focused($focus, equals: .iban)
                        .talerFont(.title3)
                        .foregroundColor(WalletColors().fieldForeground)     // text color
                        .background(WalletColors().fieldBackground)
                        .textFieldStyle(.roundedBorder)
                } else if paytoType == .xTalerBank {
                    TextField(paytoStr, text: $xTaler)
                        .accessibilityLabel(paytoColon)
                        .focused($focus, equals: .xTaler)
                        .talerFont(.title3)
                        .foregroundColor(WalletColors().fieldForeground)     // text color
                        .background(WalletColors().fieldBackground)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text("unknown payment method")
                }
            }.padding(.bottom)


            if currencies.count == 1 {
                let currency = currencies[0]
                Text(minimalistic ? currency
                                  : "Currency: \(currency)")
            } else if currencies.count > 1 {
                if !minimalistic {
                    Text("Currencies:")
                }
                ForEach (currencies, id: \.self) { currency in
                    Text(currency)
                        .padding(.leading)
                }
            }

            let note = String(localized: "Note")
            let noteColon = String("\(note):")
            if !minimalistic {
                Text(noteColon)
                    .talerFont(.title3)
                    .accessibilityHidden(true)
            }
            TextField(minimalistic ? note : EMPTYSTRING, text: $label)
                .accessibilityLabel(noteColon)
                .focused($focus, equals: .label)
                .talerFont(.title2)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)
            Button {
                deleteAccount()
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
                .buttonStyle(TalerButtonStyle(type: .bordered, disabled: disabled))
                .disabled(disabled)
        }.listRowSeparator(.hidden)
        } // List
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
