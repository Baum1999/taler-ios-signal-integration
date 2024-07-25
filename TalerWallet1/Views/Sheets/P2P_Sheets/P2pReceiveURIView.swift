/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called either by the user scanning a QR code or tapping the provided link,
// from another user's SendCoins. We show the P2P details - but first the ToS must be accepted.
struct P2pReceiveURIView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let currencyInfo: CurrencyInfo

    // the scanned URL
    let url: URL
    
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var peerPushCreditResponse: PreparePeerPushCreditResponse? = nil
    @State private var exchange: Exchange? = nil

    let navTitle = String(localized: "P2P Receive")

    var body: some View {
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
                                 currencyInfo: currencyInfo,
                                     topTitle: String(localized: "Gross Amount to receive:"),
                                    topAbbrev: String(localized: "Receive gross:", comment: "mini"),
                                    topAmount: raw, fee: fee,
                                  bottomTitle: String(localized: "Net Amount to receive:"),
                                 bottomAbbrev: String(localized: "Receive net:", comment: "mini"),
                                 bottomAmount: effective,
                                        large: false, pending: false, incoming: true,
                                      baseURL: nil,
                                       noFees: nil,        // TODO: check baseURL for fees
                                   txStateLcl: nil,
                                      summary: peerPushCreditResponse.contractTerms.summary,
                                     merchant: nil)
                    let expiration = peerPushCreditResponse.contractTerms.purse_expiration
                    let (dateString, date) = TalerDater.dateString(from: expiration)
                    let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
                    let a11yLabel = String(localized: "Expires: \(a11yDate)", comment: "VoiceOver")
                    Text("Expires: \(dateString)")
                        .talerFont(.body)
                        .accessibilityLabel(a11yLabel)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                if tosAccepted {
                    NavigationLink(destination: LazyView {
                        P2pAcceptDone(stack: stack.push(),
                              transactionId: peerPushCreditResponse.transactionId,
                                   incoming: true)
                    }) {
                        Text("Accept P2P Receive")      // SHEET_RCV_P2P_ACCEPT
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
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
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_RCV_P2P)
        }
        .task { // must be here and not at LoadingView(), because this needs to run a 2nd time after ToS was accepted
            symLog.log(".task")
            if let ppResponse = try? await model.preparePeerPushCreditM(url.absoluteString) {
                exchange = try? await model.getExchangeByUrl(url: ppResponse.exchangeBaseUrl)
                peerPushCreditResponse = ppResponse
            } else {
                peerPushCreditResponse = nil
            }
        }
    }
}
