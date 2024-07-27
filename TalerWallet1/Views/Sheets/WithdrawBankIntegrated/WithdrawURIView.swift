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

// Called either when scanning a QR code or tapping the provided link, both from the bank's website.
// We show the user the bank-integrated withdrawal details in a sheet - but first the ToS must be accepted.
// After the user confirmed the withdrawal, we show a button to return to the bank website to confirm there, too
struct WithdrawURIView: View {
    private let symLog = SymLogV()
    let stack: CallStack

    // the URL from the bank website
    let url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var withdrawUriInfo: WithdrawUriInfoResponse? = nil
    @State private var currencyName = EMPTYSTRING
    @State private var amountIsEditable = false
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var buttonSelected = false
    @State private var shortcutSelected = false
    @State private var amountAvailable: Amount? = nil
    @State private var wireFee: Amount? = nil
    @State private var summary = EMPTYSTRING

    @State private var selectedExchange = EMPTYSTRING
    @State private var exchange: Exchange? = nil
    @State private var possibleExchanges: [Exchange] = []
    @State private var defaultExchangeBaseUrl: String?     // if nil then use possibleExchanges
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)

//    @State private var feeAmount: Amount? = nil
    @State private var withdrawalAmountDetails: WithdrawalAmountDetails? = nil

    let navTitle = String(localized: "Withdrawal")

    func loadExchange(_ baseUrl: String) async {        // TODO: throws?
        if let someExchange = try? await model.getExchangeByUrl(url: baseUrl) {
            symLog.log("Loaded \(baseUrl.trimURL())")
            exchange = someExchange
        }
    }

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        shortcutSelected = true
    }
    private func buttonAction() {
        buttonSelected = true
    }

    private func feeLabel(_ feeString: String) -> String {
        feeString.count > 0 ? String(localized: "\(feeString) fee")
        : EMPTYSTRING
    }

    private func computeFeeWithdraw(_ amount: Amount) async -> ComputeFeeResult? {
        if let exchange {
            if let details = try? await model.getWithdrawalDetailsForAmountM(exchange.exchangeBaseUrl,
                                                                      amount: amount) {
                let fee = try? details.amountRaw - details.amountEffective
                let feeStr = fee?.formatted(currencyInfo, isNegative: true) ?? "nix"
                symLog.log("Fee = \(feeStr)")
                let insufficient = if let amountAvailable {
                    (try? details.amountRaw < amountAvailable) ?? true
                } else {
                    false
                }
                withdrawalAmountDetails = details
                return ComputeFeeResult(insufficient: insufficient, feeAmount: fee,
                                        feeStr: feeLabel(feeStr), numCoins: details.numCoins)
            }
        } else {
            symLog.log("No exchange!")
        }
        return nil
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if possibleExchanges.count > 0 {
            if let defaultBaseUrl = defaultExchangeBaseUrl ?? possibleExchanges.first?.exchangeBaseUrl {
                VStack {
                    let title = String(localized: "using:", comment: "using: exchange.taler.net")
                    if possibleExchanges.count > 1 {
                        Picker(title, selection: $selectedExchange) {
                            ForEach(possibleExchanges, id: \.self) { exchange in
                                let baseUrl = exchange.exchangeBaseUrl
                                Text(baseUrl)
                            }
                        }
                        .talerFont(.title3)
                        .pickerStyle(.menu)
                        .onAppear() {
                            withAnimation { selectedExchange = defaultBaseUrl }
                        }
                        .onChange(of: selectedExchange) { selected in
                            Task {
                                await loadExchange(selected)
                            }
                        }
                    } else {
                        HStack {
                            Text(title)
                            Text(defaultBaseUrl.trimURL())
                        }
                        .talerFont(.body)
//                        .task {
//                            await loadExchange(defaultBaseUrl)
//                        }
                    } // load defaultBaseUrl
                    let acceptDestination = WithdrawAcceptView(stack: stack.push(),
                                                        currencyInfo: $currencyInfo,
                                                                 url: url,
                                                    amountToTransfer: $amountToTransfer,
                                                             wireFee: $wireFee,
                                                            exchange: $exchange)
                    if amountIsEditable {
                        ScrollView {
                            let shortcutDestination = LazyView {
                                WithdrawAcceptView(stack: stack.push(),
                                            currencyInfo: $currencyInfo,
                                                     url: url,
                                        amountToTransfer: $amountShortcut,
                                                 wireFee: $wireFee,
                                                exchange: $exchange)
                            }
                            // TODO: input amount, then
                            let amountLabel = minimalistic ? String(localized: "Amount:")
                                                           : String(localized: "Amount to withdraw:")
                            AmountInputV(stack: stack.push(),
                                  currencyInfo: $currencyInfo,
                               amountAvailable: amountAvailable,
                                   amountLabel: amountLabel,
                              amountToTransfer: $amountToTransfer,
                                       wireFee: wireFee,
                                       summary: $summary,
                                shortcutAction: shortcutAction,
                                  buttonAction: buttonAction,
                                 feeIsNegative: true,
                                    computeFee: computeFeeWithdraw)
                            .background(NavigationLink(destination: shortcutDestination, isActive: $shortcutSelected)
                                        { EmptyView() }.frame(width: 0).opacity(0).hidden()
                            ) // shortcutDestination
                            .background(NavigationLink(destination: acceptDestination, isActive: $buttonSelected)
                                        { EmptyView() }.frame(width: 0).opacity(0).hidden()
                            ) // acceptDestination
                        } // ScrollView
                    } else {
                        acceptDestination
                    } // directly show the accept view
                }
                .navigationTitle(navTitle)
                .task(id: controller.currencyTicker) {
                    let currency = amountToTransfer.currencyStr
                    currencyInfo = controller.info(for: currency, controller.currencyTicker)
                    currencyName = currencyInfo.scope.currency
                }
                .onAppear() {
                    symLog.log("onAppear")
                    DebugViewC.shared.setSheetID(SHEET_WITHDRAWAL)
                }
//                    agePicker.setAges(ages: details?.ageRestrictionOptions)
            } else {    // TODO: error
//                symLog.log("no exchangeBaseUrl or no exchange")
            }


        } else {        // no details or no exchange
#if DEBUG
            let message = url.host
#else
            let message: String? = nil
#endif
            LoadingView(scopeInfo: nil, message: message)
                .task {
                    symLog.log(".task")
                    if let uriInfoResponse = try? await model.getWithdrawalDetailsForUriM(url.absoluteString) {
                        let amount = uriInfoResponse.amount
                        let currency = amount?.currencyStr ?? uriInfoResponse.currency
                        amountToTransfer = amount ?? Amount.zero(currency: currency)
                        amountIsEditable = uriInfoResponse.editableAmount
                        amountAvailable = uriInfoResponse.maxAmount     // may be nil
                        wireFee = uriInfoResponse.wireFee               // may be nil
                        let baseUrl = uriInfoResponse.defaultExchangeBaseUrl
                                   ?? uriInfoResponse.possibleExchanges[0].exchangeBaseUrl
                        defaultExchangeBaseUrl = uriInfoResponse.defaultExchangeBaseUrl
                        possibleExchanges = uriInfoResponse.possibleExchanges
                        await loadExchange(baseUrl)
                        symLog.log("\(baseUrl.trimURL()) loaded")
                        await controller.checkInfo(for: baseUrl, model: model)
                        symLog.log("Info(for: \(baseUrl.trimURL())) loaded")
                    }

                    // TODO: amount = nil ==> show amount input
                } // getWithdrawalDetailsForUriM
        }
    }
}
