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
///    [􁉇Send]  [􁉅Request]
/// [􁾭Withdraw]  [􁾩Deposit]
///        [􀎻  Scan QR ]
struct ActionsSheet: View {
    let stack: CallStack
    @Binding var qrButtonTapped: Bool

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
    private var canSend: Bool {     // canDeposit
        for balance in controller.balances {
            if !balance.available.isZero {
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
                        let talerColor = WalletColors().talerColor
                        ButtonIconBadge(type: .payment, foreColor: talerColor, done: false)
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

            let sendDisabled = !canSend
            let recvDisabled = controller.balances.count == 0
            SendRequestV(stack: stack.push(), sendDisabled: sendDisabled, recvDisabled: recvDisabled)
            DepositWithdrawV(stack: stack.push(), sendDisabled: sendDisabled, recvDisabled: recvDisabled)
            QRButton(isNavBarItem: false) {
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
    @Binding var qrButtonTapped: Bool

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
        ScrollView {
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
                if newValue == scanDetent {
                    logger.trace("onChange❗️selectedDetent = \(SCANDETENT)")
                    updateDetentsWithDelay()
                    qrButtonTapped = true           // tell our caller
                } else {
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
    }
}
