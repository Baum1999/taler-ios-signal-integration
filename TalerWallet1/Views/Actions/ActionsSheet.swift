/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import os.log
import taler_swift

struct ScannedURLs: View {
    let stack: CallStack
//    @Environment(\.openURL) private var openURL       NEVER EVER use this to pass a URL to myself - iOS might open another app
    @EnvironmentObject private var controller: Controller

    var body: some View {
        VStack {
            Text("Scanned Taler codes:")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, -2)
            ForEach(controller.scannedURLs) { scannedURL in
                let action = {
                    dismissTop(stack.push())
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        // need to wait before opening the next sheet, otherwise SwiftUI doesn't update!
                        // openURL(scannedURL.url)              don't do this - iOS might open another wallet app
                        controller.talerURI = scannedURL.url    // instead pass it via .onChange(of: controller.talerURI) directly to MainView
                    }
                }
                Button(action: action) {
                    HStack {
                        Text(scannedURL.command.localizedCommand)
                        let primaryAccent = WalletColors().primaryAccent
                        ButtonIconBadge(type: scannedURL.command.transactionType,
                                       phase: 0,
                                   foreColor: primaryAccent,
                                        done: false)
                        .talerFont(.title2)

                        Spacer()
                        if let amount = scannedURL.amount {
                            AmountV(scannedURL.scope, amount, isNegative: nil)
                        } else if let baseURL = scannedURL.baseURL {
                            Text(baseURL.trimURL)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                .swipeActions(edge: .trailing) {
                    Button {
                        //                                symLog?.log("deleteAction")
                        Task { // runs on MainActor
                            controller.removeURL(scannedURL.url)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(WalletColors().negative)
                }

            }
        }.padding(.bottom, 20)
    }
}
// MARK: -
/// This view shows the action sheet
/// optional:   [􀰟Spend KUDOS]
///   [􁉇 Send   ] [􁉅 Request]
///   [􁾩Deposit] [􁾭 Withdraw]
///        [􀎻  Scan QR ]
struct ActionsSheet: View {
    let stack: CallStack

    @EnvironmentObject private var controller: Controller
    @AppStorage("demoHints") var demoHints: Bool = true
    @AppStorage("pasteAutomatically") var pasteAutomatically: Bool = false

    private var hasKudos: Bool {
        for balance in controller.balances {
            if balance.scopeInfo.currency == DEMOCURRENCY {
                if !balance.available.isZero {
                    return true
                }
            }
        }
        return false
    }
    private var mayDeposit: Bool { // returns true if at least 1 balance didn't disable deposits
        for balance in controller.balances {
            if !(balance.disableDirectDeposits == true) {       // false or nil
                return true
            }
        }
        return false
    }
    private var mayP2P: Bool { // returns true if at least 1 balance didn't disable P2P
        for balance in controller.balances {
            if !(balance.disablePeerPayments == true) {         // false or nil
                return true
            }
        }
        return false
    }

    var body: some View {
        VStack {
            Spacer(minLength: 4)                    // leave space under presentationDragIndicator
                .frame(maxHeight: 8)

            if let balance = controller.balances.first,
               let shoppingUrls = balance.shoppingUrls,
               !shoppingUrls.isEmpty
            {
                let currency = balance.scopeInfo.currency
                ShoppingView(stack: stack.push(),
                          currency: currency,
                       buttonTitle: String(localized: "LinkTitle_SHOPS", defaultValue: "Where to pay with \(currency)"),
                    buttonA11yHint: String(localized: "Will go to the map of shops.", comment: "a11y"),
                        buttonLink: shoppingUrls.first!)
            } else if hasKudos && demoHints {
                ShoppingView(stack: stack.push(),
                          currency: nil,
                       buttonTitle: String(localized: "LinkTitle_DEMOSHOP", defaultValue: "Spend demo money"),
                    buttonA11yHint: String(localized: "Will go to the demo shop website.", comment: "a11y"),
                        buttonLink: DEMOSHOP)
            }
            if !controller.scannedURLs.isEmpty {
                ScannedURLs(stack: stack.push())
            }

            let noBalances = controller.balances.isEmpty
            let noP2P = !self.mayP2P
            let sendDisabled = noP2P
            let recvDisabled = noBalances || noP2P
            let depoDisabled = !mayDeposit
            TimelineView(.periodic(from: .now, by: 60/80)) { context in
                PhaseView(stack: stack.push(), date: context.date,
                   sendDisabled: sendDisabled, recvDisabled: recvDisabled,
                   depoDisabled: depoDisabled, wthdDisabled: noBalances)
            }
            HStack {
                if #available(iOS 26.0, *) {
                    if !pasteAutomatically {
#if TALER_NIGHTLY
                        PasteButton(supportedContentTypes: [.url]) { providers in
                            for provider in providers {
                                if provider.canLoadObject(ofClass: String.self) {
                                    _ = provider.loadObject(ofClass: String.self) { string, error in
                                        guard let string else { return }
                                        if let pastedURL = string.toURL {
                                            let scheme = pastedURL.scheme
                                            if scheme?.lowercased() == "taler" {
                                                let pasteType = PasteType(pastedURL: pastedURL)
                                                let userinfo = [NOTIFICATIONPASTE: pasteType]
                                                NotificationCenter.default.post(name: .PasteAction, object: nil, userInfo: userinfo)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .labelStyle(.iconOnly)
                        .tint(WalletColors().primaryAccent)
                        .buttonBorderShape(.circle) // capsule
                        .accessibility(sortPriority: 1)
#else
                        let isEnabled = UIPasteboard.general.hasURLs
                        TalerPasteButton(accessibilityLabelStr: "Paste") {
                            Task {
                                TalerWallet1App().inspectPasteboard(playSound: true)
                            }
                        }.buttonStyle(TalerButtonStyle(type: .bordered,
                                                     dimmed: false,
                                                     narrow: true,
                                                   disabled: !isEnabled,
                                                    aligned: .center))
                        .accessibility(sortPriority: 1)
#endif
                    }
                    Spacer(minLength: 8)
                }
                ///   [􀎻  Scan QR ]
                QRButton(hideTitle: false) {
                    Task {
                        NotificationCenter.default.post(name: .QrScanAction, object: nil)   // will
                    }
                }
                    .lineLimit(5)
                    .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .center))
                    .accessibility(sortPriority: 3)     // read this first
            }
        }
        .padding(.top)
        .padding(.horizontal)
        .padding(.bottom, -8)
        .accessibilityElement(children: .contain)
    }
}
// MARK: -
struct ShoppingView: View {
    let stack: CallStack
    let currency: String?
    let buttonTitle: String
    let buttonA11yHint: String
    let buttonLink: String

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        Group {
            if let currency {
                Text(minimalistic ? "Spend your \(currency) in these shops:"
                                  : "You can spend your \(currency) in these shops, or send them to another wallet.")
            } else {
                Text(minimalistic ? "Spend your \(DEMOCURRENCY) in the Demo shop"
                                  : "You can spend your \(DEMOCURRENCY) in the Demo shop, or send them to another wallet.")
            }
        }
            .talerFont(.body)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)           // must set this otherwise fixedInnerHeight won't work

        let image = Image(systemName: currency == nil ? LINK : MAPPIN)          // 􀉣 or 􀎫
        Button("\(image) \(buttonTitle)") {
            UIApplication.shared.open(URL(string: buttonLink)!, options: [:])
            dismissTop(stack.push())
        }
            .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
            .accessibilityLabel(buttonTitle)
            .accessibilityAddTraits(.isLink)
            .accessibilityHint(buttonA11yHint)
            .padding(.bottom, 20)
    }
}
// MARK: -
@available(iOS 16.4, *)
struct DualHeightSheet: View {
    let stack: CallStack
    let selectedBalance: Balance?
    let dismissScanner: () -> Void

    let logger = Logger(subsystem: "net.taler.gnu", category: "DualSheet")
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @AppStorage("minimalistic") var minimalistic: Bool = false
//    @State private var selectedDetent: PresentationDetent = scanDetent        // Cannot use instance member 'scanDetent' within property initializer
    @State private var selectedDetent: PresentationDetent = .fraction(0.1)      // workaround - update in .task
    @State private var supportedDetents: Set<PresentationDetent> = [.fraction(0.1)]      //   "
//    @State private var qrButtonTapped2: Bool = false
    @State private var scannedCode: Bool = false
    @State private var innerHeight: CGFloat = .zero
    @State private var sheetHeight: CGFloat = .zero

    let halfDetent: PresentationDetent = .fraction(HALFDETENT)
    let fullDetent: PresentationDetent = .fraction(FULLDETENT)

    func updateDetentsWithDelay() {
        Task {
            //(1 second = 1_000_000_000 nanoseconds)
            try? await Task.sleep(nanoseconds: 80_000_000)
            let detent = minimalistic ? halfDetent : fullDetent
            guard selectedDetent == detent else { return }
            supportedDetents = [detent]
            logger.trace("updateDetentsWithDelay❗️supportedDetents = [scanDetent]")      // 0.999 %
        }
    }

    func actionsSheet() -> some View {
        let actionsSheet = ActionsSheet(stack: stack.push())
                            .presentationDragIndicator(.visible)
        if #available(iOS 28.0, *) {        // TODO: adapt ActionsSheet() to glass-buttons
            return actionsSheet
                .presentationSizing(.fitted) // iOS 18+
        } else {
            let background = colorScheme == .dark ? WalletColors().gray6
                                                  : WalletColors().gray2
            return actionsSheet
                .presentationBackground {
                    background
                    /// overflow the bottom of the screen by a sufficient amount to fill the gap that is seen when the size changes
                        .padding(.bottom, -1000)
                }
        }
    }

    var body: some View {
        let scrollView = ScrollView {
            actionsSheet()
            .innerHeight($innerHeight)
//            .onChange(of: qrButtonTapped2) { tapped2 in
//                if tapped2 {
////                    logger.trace("❗️the user tapped")
//                    NotificationCenter.default.post(name: .QrScanAction, object: nil)   // will trigger
//                    withAnimation(Animation.easeIn(duration: 0.6)) {
//                        // animate this sheet to full height
//                        let detent = minimalistic ? halfDetent : fullDetent
//                        logger.trace("qrButtonTapped2❗️selected_Detent = \(FULLDETENT)")
//                        selectedDetent = detent
//                    }
//                }
//            }
//            .onChange(of: qrButtonTapped) { tapped in
//                if !tapped {
//                    logger.trace("❗️dismissed, cleanup")
//                    sheetHeight = innerHeight
//                    qrButtonTapped2 = false
//                }//tapped
//            }//qr
            .onChange(of: innerHeight) { newHeight in
                logger.trace("onChange❗️innerHeight => set sheetHeight: \(sheetHeight) -> \(newHeight)❗️")
                sheetHeight = newHeight
                selectedDetent = .height(newHeight)         // will update supportedDetents in .onChange(:)
                logger.trace("did set selectedDetent and sheetHeight to new innerHeight")
            }
            .presentationDetents(supportedDetents, selection: $selectedDetent)
            .onChange(of: selectedDetent) { newValue in
                let detent = minimalistic ? halfDetent : fullDetent
                if newValue == detent {    // user swiped the sheet up to activate QR scanner
                    logger.trace("onChange❗️selectedDetent == (detent) ==> updateDetentsWithDelay()")
                    updateDetentsWithDelay()
                    NotificationCenter.default.post(name: .QrScanAction, object: nil)   // will trigger
                } else {    // SwiftUI "innerHeight" determined how big the half sheet should be
                    logger.trace("onChange❗️selectedDetent = .height(\(sheetHeight))  supportedDetents = [detent, .height(sheetHeight)]")
                    supportedDetents = [detent, newValue]
//                    logger.trace("did set supportedDetents to [\(detent), .height(\(sheetHeight))]")
                    let _ = print("did set supportedDetents to [\(detent), newValue: \(newValue))]")
                }
            }
            .task {
                logger.trace("task❗️selectedDetent = .height(\(sheetHeight))")
                selectedDetent = .height(sheetHeight)       // will update supportedDetents in .onChange(:)
            }
//            .animation(.spring(), value: selectedDetent)
        }
        .ignoresSafeArea()
        .frame(maxHeight: innerHeight)

        if #available(iOS 18.0, *) {
            scrollView
//                .sheet(isPresented: $qrButtonTapped,
//                         onDismiss: dismissScanner
//                ) {
//                    let qrSheet = AnyView(QRSheet(stack: stack.push(".sheet"),
//                                        selectedBalance: selectedBalance,
//                                       scannedSomething: $scannedCode))
//                    let detent: PresentationDetent = .fraction(scannedCode ? FULLDETENT
//                                                            : minimalistic ? HALFDETENT : FULLDETENT)
//                    Sheet(stack: stack.push(), sheetView: qrSheet)
//                        .presentationDetents([detent])
//                        .transition(.opacity)
//                }
                .defaultScrollAnchor(.top)
        } else {
            scrollView
        }
    }
}
