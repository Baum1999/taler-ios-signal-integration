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
    let url: URL                        // the scanned URL
    let oimEuro: Bool

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @StateObject private var cash: OIMcash
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var peerPushCreditResponse: PreparePeerPushCreditResponse? = nil
    @State private var accept: Bool = false
    @State private var exchange: Exchange? = nil
    @Namespace var namespace

    let navTitle = String(localized: "Receive", comment: "Nav Title")

    // Since there is no selectedBalance, we cannot know which currency we'll need to render at this time
    init(stack: CallStack, url: URL, oimEuro: Bool) {
        self.stack = stack
        self.url = url
        self.oimEuro = oimEuro
//        let oimCurrency = oimCurrency(selectedBalance.wrappedValue?.scopeInfo)  // might be nil ==> OIMeuros
        let oimCurrency = oimCurrency(nil, oimEuro: oimEuro)                    // nil ==> OIMeuros
        let oimCash = OIMcash(oimCurrency)
        self._cash = StateObject(wrappedValue: { oimCash }())
    }

    @MainActor
    private func viewDidLoad() async {
        symLog.log(".task")
        if let ppResponse = try? await model.preparePeerPushCredit(url.absoluteString) {
            let baseUrl = ppResponse.exchangeBaseUrl
            exchange = try? await model.getExchangeByUrl(url: baseUrl)
            await controller.checkCurrencyInfo(for: baseUrl, model: model)
            let oimCurrency = oimCurrency(ppResponse.scopeInfo, oimEuro: oimEuro)
            cash.setCurrency(oimCurrency)
            controller.removeURL(url)       // tx is now saved by wallet-core
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
                let scope = peerPushCreditResponse.scopeInfo
                let balance = controller.balance(for: scope)
                let tosAccepted = exchange?.tosStatus == .accepted
                if !tosAccepted {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: peerPushCreditResponse.exchangeBaseUrl,
                                 viewID: SHEET_RCV_P2P_TOS,
                                    p2p: true,
                           acceptAction: nil)
                }
                List {
                    PeerPushCreditView(stack: stack.push(),
                                         raw: peerPushCreditResponse.amountRaw,
                                   effective: peerPushCreditResponse.amountEffective,
                                      isDone: false,
                                       scope: peerPushCreditResponse.scopeInfo,
                                     summary: peerPushCreditResponse.contractTerms.summary)
                    ExpiresView(expiration: peerPushCreditResponse.contractTerms.purse_expiration)
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                .task(id: controller.currencyTicker) {
                    let currency = peerPushCreditResponse.amountRaw.currencyStr
                    currencyInfo = controller.info2(for: currency, controller.currencyTicker)
                }
                .safeAreaInset(edge: .bottom) {
                    if peerPushCreditResponse.txState.isConfirmed {
                        Button("Done") { dismissTop(stack.push()) }
                            .buttonStyle(TalerButtonStyle(type: .prominent))
                            .padding(.horizontal)
                    } else {
                        if tosAccepted {
                            PeerPushCreditAccept(stack: stack.push(), url: url,
                                         transactionId: peerPushCreditResponse.transactionId,
                                                accept: $accept)
                        }
                    }
                }
#if OIM && DEBUG
                .overlay { if #available(iOS 16.4, *) {
                    if controller.oimSheetActive {
                        OIMp2pReceiveView(stack: stack.push(),
                                           cash: cash,
                                      available: balance?.available,
                         peerPushCreditResponse: $peerPushCreditResponse,
                                fwdButtonTapped: $accept)
                        .environmentObject(NamespaceWrapper(namespace))             // keep OIMviews apart
                    }
                } }
#endif
            } else {
#if DEBUG
                let message = url.host
#else
                let message: String? = nil
#endif
                LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
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
// MARK: -
struct PeerPushCreditAccept: View  {
    let stack: CallStack
    let url: URL?
    let transactionId: String
    @Binding var accept: Bool           // triggers 'destination' when set true

    var body: some View {
        let destination = P2pAcceptDone(stack: stack.push(),
                                          url: url,
                                transactionId: transactionId,
                                     incoming: true)
        let actions = Group {
            NavLink($accept) { destination }
        }
        Button("Accept and receive") {      // SHEET_RCV_P2P_ACCEPT
            accept = true
        }
        .background(actions)
        .buttonStyle(TalerButtonStyle(type: .prominent))
        .padding(.horizontal)
    }
}
// MARK: -
struct PeerPushCreditView: View  {
    let stack: CallStack
    let raw: Amount
    let effective: Amount
    let isDone: Bool
    let scope: ScopeInfo?
    let summary: String

    var body: some View {
        let fee = try! Amount.diff(raw, effective)
        ThreeAmountsSection(stack: stack.push(),
                            scope: scope,
                         topTitle: String(localized: "Gross Amount to receive:"),
                        topAbbrev: String(localized: "Receive gross:", comment: "mini"),
                        topAmount: raw,
                           noFees: nil,        // TODO: check baseURL for fees
                              fee: fee,
                      bottomTitle: String(localized: "Net Amount to receive:"),
                     bottomAbbrev: String(localized: "Receive net:", comment: "mini"),
                     bottomAmount: effective,
                            large: false,
                    pendingDialog: false,
                           isDone: isDone,
                         incoming: true,
                          baseURL: nil,
                       txStateLcl: nil,
                          summary: summary,
                         products: nil)
    }
}
// MARK: -
struct ExpiresView: View  {
    let expiration: Timestamp?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false
    var body: some View {
        if let expiration {
            let (dateString, date) = TalerDater.dateString(expiration, minimalistic)
            let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
            let a11yLabel = String(localized: "Expires: \(a11yDate)", comment: "a11y")
            Text("Expires: \(dateString)")
                .talerFont(.body)
                .accessibilityLabel(a11yLabel)
                .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
        } else { // should never happen
            Text("Unknown Expiration")
                .talerFont(.body)
                .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
        }
    }
}
