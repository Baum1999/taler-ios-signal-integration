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

// Called either when scanning a QR code or tapping the provided link, both from the bank's website.
// We show the user the bank-integrated withdrawal details in a sheet - but first the ToS must be accepted.
// After the user confirmed the withdrawal, we show a button to return to the bank website to authorize (2FA)
struct WithdrawURIView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    // the URL from the bank website
    let url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var withdrawUriInfo: WithdrawUriInfoResponse? = nil
    @State private var amountIsEditable = false
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var amountZero = Amount.zero(currency: EMPTYSTRING)          // needed for isZero
    @State private var amountLastChecked = Amount.zero(currency: EMPTYSTRING)   //
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
    @State private var withdrawalDetails: WithdrawalDetailsForAmount? = nil

    let navTitle = String(localized: "Withdrawal")

    @MainActor
    func loadExchange(_ baseUrl: String) async {        // TODO: throws?
        if let someExchange = try? await model.getExchangeByUrl(url: baseUrl) {
            symLog.log("Loaded \(baseUrl.trimURL)")
            exchange = someExchange
        }
    }

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        shortcutSelected = true
    }
    private func buttonAction() { buttonSelected = true }

    private func feeLabel(_ feeString: String) -> String {
        feeString.count > 0 ? String(localized: "\(feeString) fee")
        : EMPTYSTRING
    }

    @MainActor
    private func computeFeeWithdraw(_ amount: Amount) async -> ComputeFeeResult? {
        if let exchange {
          if amountLastChecked != amount {
            amountLastChecked = amount

            if let details = try? await model.getWithdrawalDetailsForAmount(amount,
                                                                   baseUrl: exchange.exchangeBaseUrl,
                                                                     scope: nil) {     // TODO: scope
                let fee = try? details.amountRaw - details.amountEffective
                let feeStr = fee?.formatted(currencyInfo, isNegative: true) ?? ("0", "0")
                symLog.log("Fee = \(feeStr.0)")
                let insufficient = if let amountAvailable {
                    (try? details.amountRaw < amountAvailable) ?? true
                } else {
                    false
                }
                withdrawalDetails = details
                return ComputeFeeResult(insufficient: insufficient, feeAmount: fee,
                                              feeStr: (feeLabel(feeStr.0), feeLabel(feeStr.1)),
                                            numCoins: details.numCoins)
            } else {
                // TODO: don't call this again
            }
          }
        } else {
            symLog.log("No exchange!")
        }
        return nil
    }

    @MainActor
    private func viewDidLoad() async {
        symLog.log(".task")
        do {
            let uriInfoResponse = try await model.getWithdrawalDetailsForUri(url.absoluteString)
            let amount = uriInfoResponse.amount
            let currency = amount?.currencyStr ?? uriInfoResponse.currency
            amountToTransfer = amount ?? Amount.zero(currency: currency)
            amountIsEditable = uriInfoResponse.editableAmount
            amountAvailable = uriInfoResponse.maxAmount     // may be nil
            if let available = amountAvailable {
                amountZero = available
            }
            wireFee = uriInfoResponse.wireFee               // may be nil
            let baseUrl = uriInfoResponse.defaultExchangeBaseUrl
                       ?? uriInfoResponse.possibleExchanges[0].exchangeBaseUrl
            defaultExchangeBaseUrl = uriInfoResponse.defaultExchangeBaseUrl
            possibleExchanges = uriInfoResponse.possibleExchanges

//            await loadExchange(baseUrl)       <- checkCurrencyInfo now returns the exchange
//            symLog.log("\(baseUrl.trimURL) loaded")

            if let someExchange = try? await controller.checkCurrencyInfo(for: baseUrl, model: model) {
                symLog.log("Info(for: \(baseUrl.trimURL) loaded")
                exchange = someExchange
            }
        } catch {
            // TODO: error, dismiss
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(url.absoluteString)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if let exchange2 = exchange {
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
                        .onAppear() {  selectedExchange = defaultBaseUrl }
                        .onChange(of: selectedExchange) { selected in
                            Task { await loadExchange(selected) }
                        }
                    } // load defaultBaseUrl
                    let acceptDestination = WithdrawAcceptView(stack: stack.push(),
                                                                 url: url,
                                                               scope: exchange2.scopeInfo,
                                                    amountToTransfer: $amountToTransfer,
                                                             wireFee: $wireFee,
                                                            exchange: $exchange)        // from possibleExchanges
                    if amountIsEditable {
                        ScrollView {
                            let shortcutDest = WithdrawAcceptView(stack: stack.push(),
                                                                    url: url,
                                                                  scope: exchange2.scopeInfo,
                                                       amountToTransfer: $amountShortcut,
                                                                wireFee: $wireFee,
                                                               exchange: $exchange)    // from possibleExchanges
                            let actions = Group {
                                NavLink($shortcutSelected) { shortcutDest }
                                NavLink($buttonSelected) { acceptDestination }
                            }
                            let a11yLabel = String(localized: "Amount to withdraw:", comment: "a11y, no abbreviations")
                            let amountLabel = minimalistic ? String(localized: "Amount:")        // maxAmount
                                                           : a11yLabel
                            // TODO: input amount, then
                            AmountInputV(stack: stack.push(),
                                         scope: exchange2.scopeInfo,
                               amountAvailable: $amountZero,
                                   amountLabel: amountZero.isZero ? amountLabel : nil,
                                     a11yLabel: a11yLabel,
                              amountToTransfer: $amountToTransfer,
                                amountLastUsed: amountLastUsed,
                                       wireFee: wireFee,
                                       summary: $summary,
                                shortcutAction: shortcutAction,
                                  buttonAction: buttonAction,
                                    isIncoming: true,
                                    computeFee: computeFeeWithdraw)
                            .background(actions)
                        } // ScrollView
                    } else {
                        acceptDestination
                    } // directly show the accept view
                }
                .navigationTitle(navTitle)
                .task(id: controller.currencyTicker) {
                    currencyInfo = controller.info(for: exchange2.scopeInfo, controller.currencyTicker)
                }
                .onAppear() {
                    symLog.log("onAppear")
                    DebugViewC.shared.setSheetID(SHEET_WITHDRAWAL)
                }
//              agePicker.setAges(ages: details?.ageRestrictionOptions)
            }


        } else {        // no details or no exchange
#if DEBUG
            let message = url.host
#else
            let message: String? = nil
#endif
            LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
                .task { await viewDidLoad() }
        }
    }
}
