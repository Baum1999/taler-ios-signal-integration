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

    @State private var color = WalletColors().talerColor

    func updateColor() {
#if DEBUG
        color = debugAnimations ? .orange
                                : fastAnimations ? WalletColors().talerColor
                                                 : .red
#else
        color = fastAnimations ? WalletColors().talerColor
                               : WalletColors().confirm
#endif
    }
    var body: some View {
            if let amount {
                AmountV(currencyName, amount: amount, isNegative: nil)
                    .ignoresSafeArea(edges: .top)
                    .foregroundColor(color)
                    .task {
                        updateColor()
                    }
#if DEBUG
                    .onTapGesture(count: 2) {
                        if debugAnimations {
                            debugAnimations = false
                            fastAnimations = true
                        } else {
                            debugAnimations = true
                        }
                        updateColor()
                    }
#endif
                    .onTapGesture(count: 1) {
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
// MARK: -
struct OIMbackground<Content: View>: View {
    let amount: Amount?
    let currencyName: String
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
            OIMamountV(amount: amount, currencyName: currencyName)
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
