/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import os.log
import taler_swift

/// This view shows the action sheet
/// optional:   [􀰟Spend KUDOS]
///   [􁉇 Send   ] [􁉅 Request]
///   [􁾩Deposit] [􁾭 Withdraw]
///        [􀎻  Scan QR ]
struct ActionsSheet: View {
    let stack: CallStack
    @Binding var qrButtonTapped: Bool

    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("demoHints") var demoHints: Bool = true

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
            let width = UIScreen.screenWidth / 3
            RoundedRectangle(cornerRadius: 8)                                   // dropBar
                .foregroundColor(WalletColors().gray4)
                .frame(width: width + 6.5, height: 5)
                .padding(.top, 5)
                .padding(.bottom, 10)

            if hasKudos && demoHints {
                Text(minimalistic ? "Spend your \(DEMOCURRENCY) in the Demo shop"
                                  : "You can spend your \(DEMOCURRENCY) in the Demo shop, or send them to another wallet.")
                    .talerFont(.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)           // must set this otherwise fixedInnerHeight won't work

                let buttonTitle = String(localized: "LinkTitle_DEMOSHOP", defaultValue: "Spend demo money")
                let shopAction = {
//                    demoHints += 1
                    UIApplication.shared.open(URL(string:DEMOSHOP)!, options: [:])
                    dismissTop(stack.push())
                }
                Button(action: shopAction) {
                    HStack {
                        ButtonIconBadge(type: .payment, foreColor: .accentColor, done: false)
                            .talerFont(.title2)
                        Spacer()
                        Text(buttonTitle)
                        Spacer()
                    }
                }
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                .accessibilityHint(String(localized: "Will go to the demo shop website.", comment: "a11y"))
                .accessibilityAddTraits(.isLink)
                .padding(.bottom, 20)
            }
            if !controller.scannedURLs.isEmpty {
                Text("Scanned Taler codes:")
                    .talerFont(.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, -2)
                VStack {
                    ForEach(controller.scannedURLs) { scannedURL in
                        let action = {
                            dismissTop(stack.push())
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                // need to wait before opening the next sheet, otherwise SwiftUI doesn't update!
                                openURL(scannedURL.url)
                            }
                        }
                        Button(action: action) {
                            HStack {
                                Text(scannedURL.command.localizedCommand)
                                ButtonIconBadge(type: scannedURL.command.transactionType,
                                           foreColor: .accentColor, done: false)
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

            let noBalances = controller.balances.count == 0
            let noP2P = !self.mayP2P
            let sendDisabled = noP2P
            let recvDisabled = noBalances || noP2P
            let depoDisabled = !mayDeposit
            SendRequestV(stack: stack.push(), sendDisabled: sendDisabled, recvDisabled: recvDisabled)
            DepositWithdrawV(stack: stack.push(), sendDisabled: depoDisabled, recvDisabled: noBalances)
            QRButton(hideTitle: false) {
                qrButtonTapped = true
            }
                .lineLimit(5)
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .center))
        }
        .padding()
    }
}
// MARK: -
@available(iOS 16.4, *)
struct DualHeightSheet: View {
    let stack: CallStack
    let selectedBalance: Balance?
    @Binding var qrButtonTapped: Bool
    let dismissScanner: () -> Void

    let logger = Logger(subsystem: "net.taler.gnu", category: "DualSheet")
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let scanDetent: PresentationDetent = .fraction(SCANDETENT)
//    @State private var selectedDetent: PresentationDetent = scanDetent        // Cannot use instance member 'scanDetent' within property initializer
    @State private var selectedDetent: PresentationDetent = .fraction(0.1)      // workaround - update in .task
//    @State private var detents: Set<PresentationDetent> = [scanDetent]
    @State private var detents: Set<PresentationDetent> = [.fraction(0.1)]
    @State private var qrButtonTapped2: Bool = false
    @State private var innerHeight: CGFloat = .zero
    @State private var sheetHeight: CGFloat = .zero

    func updateDetentsWithDelay() {
        Task {
            //(1 second = 1_000_000_000 nanoseconds)
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard selectedDetent == scanDetent else { return }
            detents = [scanDetent]
        }
    }

    var body: some View {
        let scrollView = ScrollView {
            let background = colorScheme == .dark ? WalletColors().gray6
                                                  : WalletColors().gray2
            ActionsSheet(stack: stack.push(),
                qrButtonTapped: $qrButtonTapped2)
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                background
                /// overflow the bottom of the screen by a sufficient amount to fill the gap that is seen when the size changes
                    .padding(.bottom, -1000)
            }
            .innerHeight($innerHeight)

            .onChange(of: qrButtonTapped2) { tapped2 in
                if tapped2 {
//                    logger.trace("❗️the user tapped")
                    qrButtonTapped = true           // tell our caller
                    withAnimation(Animation.easeIn(duration: 0.6)) {
                        // animate this sheet to full height
                        selectedDetent = scanDetent
                    }
                }
            }
            .onChange(of: qrButtonTapped) { tapped in
                if !tapped {
                    logger.trace("❗️dismissed, cleanup")
                    sheetHeight = innerHeight
                    qrButtonTapped2 = false
                }
            }
            .onChange(of: innerHeight) { newHeight in
                logger.trace("onChange❗️set sheetHeight: \(sheetHeight) -> \(newHeight)❗️")
//            withAnimation {
                sheetHeight = newHeight
                selectedDetent = .height(sheetHeight)       // will update detents in .onChange(:)
//            }
            }
            .presentationDetents(detents, selection: $selectedDetent)
            .onChange(of: selectedDetent) { newValue in
                if newValue == scanDetent {    // user swiped the sheet up to full height
                    logger.trace("onChange❗️selectedDetent = \(SCANDETENT)")
                    updateDetentsWithDelay()
                    qrButtonTapped = true           // tell our caller
                } else {    // SwiftUI "innerHeight" determined how big the half sheet should be
                    logger.trace("onChange❗️selectedDetent = .height(\(sheetHeight))")
                    detents = [scanDetent, .height(sheetHeight)]
                }
            }
            .task {
                logger.trace("task❗️selectedDetent = .height(\(sheetHeight))")
                selectedDetent = .height(sheetHeight)       // will update detents in .onChange(:)
            }
//            .animation(.spring(), value: selectedDetent)
        }
        .edgesIgnoringSafeArea(.all)
        .frame(maxHeight: innerHeight)

        if #available(iOS 18.0, *) {
            scrollView
                .sheet(isPresented: $qrButtonTapped,
                         onDismiss: dismissScanner
                ) {
                    let qrSheet = AnyView(QRSheet(stack: stack.push(".sheet"),
                                        selectedBalance: selectedBalance))
                    let scanDetent: PresentationDetent = .fraction(SCANDETENT)
                    Sheet(stack: stack.push(), sheetView: qrSheet)
                        .presentationDetents([scanDetent])
                        .transition(.opacity)

                }
        } else {
            scrollView
        }
    }
}
