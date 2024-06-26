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
    let navTitle = String(localized: "Withdrawal")

    // the URL from the bank website
    let url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var withdrawUriInfo: WithdrawUriInfoResponse? = nil
    @State private var currencyName = EMPTYSTRING
    @State private var amountIsEditable = false
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var shortcutSelected = false
    @State private var wireFee: Amount? = nil

    @State private var selectedExchange = EMPTYSTRING
    @State private var exchange: Exchange? = nil
    @State private var possibleExchanges: [Exchange] = []
    @State private var defaultExchangeBaseUrl: String?     // if nil then use possibleExchanges

    func loadExchange(_ baseUrl: String) async {        // TODO: throws?
        if let someExchange = try? await model.getExchangeByUrl(url: baseUrl) {
            exchange = someExchange
        }
    }

    var body: some View {
        if possibleExchanges.count > 0 {
            if let defaultBaseUrl = defaultExchangeBaseUrl ?? possibleExchanges.first?.exchangeBaseUrl {
                VStack {
                    let title = String(localized: "Exchange")
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
                        Text(defaultBaseUrl)
                            .task {
                                await loadExchange(defaultBaseUrl)
                            }
                    }
                    if amountToTransfer.isZero {
                        // TODO: input amount, then 
                        WithdrawAcceptView(stack: stack.push(), url: url,
                                amountToTransfer: $amountToTransfer,
                                        exchange: $exchange)
                                   wireFee: wireFee,
                    } else {
                        WithdrawAcceptView(stack: stack.push(), url: url,
                                amountToTransfer: $amountToTransfer,
                                        exchange: $exchange)
                    }
                }
                .navigationTitle(navTitle)
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
                    if let someInfo = try? await model.getWithdrawalDetailsForUriM(url.absoluteString) {
                        defaultExchangeBaseUrl = someInfo.defaultExchangeBaseUrl
                        possibleExchanges = someInfo.possibleExchanges
                        amountToTransfer = someInfo.amount ?? Amount.zero(currency: someInfo.currency)
                        wireFee = someInfo.wireFee
                    }

                    // TODO: amount = nil ==> show amount input
                }
        }
    }
}
