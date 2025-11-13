/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

public let OIMBACKDARK = "tara-meinczinger-G_yCplAsnB4-unsplash"
public let OIMBACKLIGHT = "andrey-haimin-VFUTPASjhB8-unsplash"

// MARK: -
struct OIMamountV: View {
    let amount: Amount?
    let currencyName: String
    let factor: Int             // workaround because TEST has no large denominations, so we multiply with 100
    let mayChangeSpeed: Bool

    @State private var color = Color.accentColor

    init(amount: Amount?, currencyName: String, factor: Int, mayChangeSpeed: Bool = true) {
        self.amount = amount
        self.currencyName = currencyName
        self.factor = factor
        self.mayChangeSpeed = mayChangeSpeed
    }

    func updateColor() {
#if DEBUG
        color = debugAnimations ? .orange
                                : fastAnimations ? .accentColor
                                                 : .red
#else
        color = fastAnimations ? .accentColor
                               : WalletColors().confirm
#endif
    }

    var body: some View {
        if let amount {
            if let amount2 = try? amount * UInt32(factor) {         // workaround for CFA, HUF, JPY
//                print(amount2.readableDescription)
                AmountV(currencyName, amount: amount2, isNegative: nil)
                    .ignoresSafeArea(edges: .top)
                    .foregroundColor(color)
                    .task {
                        updateColor()
                    }
#if DEBUG
                    .onTapGesture(count: 2) {
                        if mayChangeSpeed {
                            if debugAnimations {
                                debugAnimations = false
                                fastAnimations = true
                            } else {
                                debugAnimations = true
                            }
                            updateColor()
                        }
                    }
#endif
                    .onTapGesture(count: 1) {
                        if mayChangeSpeed {
#if DEBUG
                            if debugAnimations {
                                debugAnimations = false
                                fastAnimations = false
                            } else {
                                fastAnimations.toggle()
                            }
#else
                            fastAnimations.toggle()
#endif
                            updateColor()
                        }
                    }
            }
        }
    }
}
// MARK: -
// shows a ZStack with backImage, and content on top
struct OIMbackground<Content: View>: View {
    var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let background = colorScheme == .dark ? OIMBACKDARK
                                              : OIMBACKLIGHT
        let backImage = Image(background)
            .resizable()
        let zStack = ZStack(alignment: .top) {
            backImage
                .ignoresSafeArea(edges: .all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            content()
        }
        if #available(iOS 16.4, *) {
            zStack
                .toolbar(.hidden, for: .navigationBar, .tabBar)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {        // Fallback on earlier versions
            zStack
//                .navigationBarTitle("")       // must set the title...
                .navigationBarHidden(true)      // before you can hide the navigation bar
//                .tabBarHidden(true)           // unfortunately this call doesn't exist
        }
    }
}
// MARK: -
//#Preview {
//    OIMbackground()
//}
