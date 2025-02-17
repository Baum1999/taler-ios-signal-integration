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

// Will be called either by the user scanning a QR code or tapping the provided link,
// from another user's Send. We show the P2P details - but first the ToS must be accepted.
struct P2pReceiveURIView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    // the scanned URL
    let url: URL
    
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var peerPushCreditResponse: PreparePeerPushCreditResponse? = nil
    @State private var exchange: Exchange? = nil

    let navTitle = String(localized: "Receive", comment: "Nav Title")

    @MainActor
    private func viewDidLoad() async {
        symLog.log(".task")
        if let ppResponse = try? await model.preparePeerPushCredit(url.absoluteString) {
            let baseUrl = ppResponse.exchangeBaseUrl
            exchange = try? await model.getExchangeByUrl(url: baseUrl)
            await controller.checkCurrencyInfo(for: baseUrl, model: model)
            peerPushCreditResponse = ppResponse
        } else {
            peerPushCreditResponse = nil
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        VStack {
            if let peerPushCreditResponse {
                let tosAccepted = exchange?.tosStatus == .accepted
                if !tosAccepted {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: peerPushCreditResponse.exchangeBaseUrl,
                                 viewID: SHEET_RCV_P2P_TOS,
                                    p2p: true,
                           acceptAction: nil)
                }
                List {
                    let raw = peerPushCreditResponse.amountRaw
                    let effective = peerPushCreditResponse.amountEffective
                    let currency = raw.currencyStr
                    let fee = try! Amount.diff(raw, effective)
                    ThreeAmountsSection(stack: stack.push(),
                                        scope: peerPushCreditResponse.scopeInfo,
                                     topTitle: String(localized: "Gross Amount to receive:"),
                                    topAbbrev: String(localized: "Receive gross:", comment: "mini"),
                                    topAmount: raw,
                                       noFees: nil,        // TODO: check baseURL for fees
                                          fee: fee,
                                  bottomTitle: String(localized: "Net Amount to receive:"),
                                 bottomAbbrev: String(localized: "Receive net:", comment: "mini"),
                                 bottomAmount: effective,
                                        large: false, pending: false, incoming: true,
                                      baseURL: nil,
                                   txStateLcl: nil,
                                      summary: peerPushCreditResponse.contractTerms.summary,
                                     merchant: nil,
                                     products: nil)
                    let expiration = peerPushCreditResponse.contractTerms.purse_expiration
                    let (dateString, date) = TalerDater.dateString(expiration, minimalistic)
                    let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
                    let a11yLabel = String(localized: "Expires: \(a11yDate)", comment: "VoiceOver")
                    Text("Expires: \(dateString)")
                        .talerFont(.body)
                        .accessibilityLabel(a11yLabel)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                .task(id: controller.currencyTicker) {
                    let currency = peerPushCreditResponse.amountRaw.currencyStr
                    currencyInfo = controller.info2(for: currency, controller.currencyTicker)
                }
                .safeAreaInset(edge: .bottom) {
                    if tosAccepted {
                        let destination = P2pAcceptDone(stack: stack.push(),
                                                transactionId: peerPushCreditResponse.transactionId,
                                                     incoming: true)
                        NavigationLink(destination: destination) {
                            Text("Accept and receive")      // SHEET_RCV_P2P_ACCEPT
                        }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                    }
                }
            } else {
#if DEBUG
                let message = url.host
#else
                let message: String? = nil
#endif
                LoadingView(scopeInfo: nil, message: message)
            }
        }
        // must be here and not at LoadingView(), because this needs to run a 2nd time after ToS was accepted
        .task { await viewDidLoad() }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_RCV_P2P)
        }
    }
}
