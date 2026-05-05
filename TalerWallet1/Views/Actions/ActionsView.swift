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

@available(iOS 17.0, *)
struct ActionsOverlay: View {
    let stack: CallStack
    @Environment(\.colorScheme) private var scheme
    @State private var isPresented: Bool = false

    var animation: Animation {
        .smooth(duration: 0.5, extraBounce: 0)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()     // tap in background to dismiss
                .fill(.primary.opacity(isPresented ? 0.33 : 0))
                .allowsHitTesting(isPresented)
                .onTapGesture {
                    isPresented = false
                }
                .animation(animation, value: isPresented)
                .ignoresSafeArea()

            MiniAction(innerScaling: 0.9, animation: animation, isPresented: $isPresented) {
                ActionsView(stack: stack.push(), isPresented: isPresented)
            } background: {
                if scheme == .dark {
                    Capsule()
                        .fill(.ultraThinMaterial)
                } else {
                    let shadow: CGFloat = 5
                    let opacity: Double = isPresented ? 0 : 0.075
                    Capsule()
                        .fill(.background)
                    //                          .fill(.red.opacity(0.2))
                        .shadow(color: .black.opacity(opacity), radius: shadow, x:  shadow, y:  shadow)
                        .shadow(color: .black.opacity(opacity), radius: shadow, x: -shadow, y: -shadow)
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 10)
        }
    }
}
// MARK: -
@available(iOS 17.0, *)
struct MiniAction<Actions: View, Background: View>: View {
    var innerScaling: CGFloat = 1
    var minimisedButtonSize: CGSize = .init(width: 60, height: 50)
    var animation: Animation
    @Binding var isPresented: Bool
    @ViewBuilder var actions: Actions
    @ViewBuilder var background: Background

    var body: some View {
        actions
        /// Disabling interaction when minimised!
            .allowsHitTesting(isPresented)
            .contentShape(.rect)
            .compositingGroup()
        /// Scaling the actions to fit into the button size using the visual effect modifier!
            .visualEffect({ [innerScaling, minimisedButtonSize, isPresented] content, proxy in
                let maxValue = max(proxy.size.width, proxy.size.height)
                let minButtonValue = min(minimisedButtonSize.width, minimisedButtonSize.height)
                let fitScale = minButtonValue / maxValue
                let modifiedInnerScale = 0.55 * innerScaling

                return content
                    .scaleEffect(isPresented ? 1 : modifiedInnerScale)
                    .scaleEffect(isPresented ? 1 : fitScale)
            })
        /// Act's like a button tap to expand actions!
            .overlay {
                if !isPresented {
                    Capsule()
                        .foregroundStyle(.clear)
                        .frame(width: minimisedButtonSize.width, height: minimisedButtonSize.height)
                        .contentShape(.capsule)
                        .onTapGesture {
                            isPresented = true
                        }
                        .transition(.identity)
                }
            }
            .background {
                background
                    .frame(
                        width: isPresented ? nil : minimisedButtonSize.width,
                        height: isPresented ? nil : minimisedButtonSize.height
                    )
                    .compositingGroup()
                /// Fading out with blur
                    .opacity(isPresented ? 0 : 1)
                /// OPTIONAL:
                    .blur(radius: isPresented ? 50 : 0)
            }
//            .fixedSize()
            .frame(
                width: isPresented ? nil : minimisedButtonSize.width,
                height: isPresented ? nil : minimisedButtonSize.height
            )
            .animation(animation, value: isPresented)
    }
}
// MARK: -
/// This view shows the action sheet
/// optional:   [􀰟Spend KUDOS]
///   [􁉇 Send   ] [􁉅 Request]
///   [􁾩Deposit] [􁾭 Withdraw]
///        [􀎻  Scan QR ]
struct ActionsView: View {
    let stack: CallStack
    let isPresented: Bool

    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var controller: Controller
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
    @MainActor
    func dismissAndPost() {
        dismissTop(stack.push())
        NotificationCenter.default.post(name: .SettingsAction, object: nil)                // will trigger NavigationLink
    }

    var body: some View {
        VStack {
            Spacer(minLength: 4)
                .frame(maxHeight: 8)
//            let width = UIScreen.screenWidth / 3
//            RoundedRectangle(cornerRadius: 8)                                   // dropBar
//                .foregroundColor(WalletColors().gray4)
//                .frame(width: width + 6.5, height: 5)
//                .padding(.top, 5)
//                .padding(.bottom, 10)

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
            ///   [􁉇 Send   ] [􁉅 Request]
            SendRequestV(stack: stack.push(), sendDisabled: sendDisabled, recvDisabled: recvDisabled)
                .accessibility(sortPriority: 1)     // read this after maps
            ///   [􁾩Deposit] [􁾭 Withdraw]
            DepositWithdrawV(stack: stack.push(), sendDisabled: depoDisabled, recvDisabled: noBalances)
                .accessibility(sortPriority: 0)     // read this last
            HStack {
                if #available(iOS 26.0, *) {
                    SettingsButton(accessibilityLabelStr: TalerTab.settings.title,
                                   action: dismissAndPost)
                    .accessibility(sortPriority: 0)     // read this last
                    Spacer()
                }
                ///   [􀎻  Scan QR ]
                QRButton(hideTitle: false) {
                    NotificationCenter.default.post(name: .QrScanAction, object: nil)   // will trigger NavigationLink
                }
                .lineLimit(5)
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .center))
                .accessibility(sortPriority: 3)     // read this first
//                .padding(.horizontal)
            }
        }
        .padding(.top)
        .padding(.horizontal)
        .padding(.bottom, -8)
        .accessibilityElement(children: .contain)
    }
}

