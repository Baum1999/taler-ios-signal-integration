/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

let DESCENDING = true

public let OIMBACKDARK = "tara-meinczinger-G_yCplAsnB4-unsplash"
public let OIMBACKLIGHT = "andrey-haimin-VFUTPASjhB8-unsplash"

fileprivate func intValue(_ amount: Amount?) -> Int {
    if let amount {
        if !amount.isZero {
            let value = amount.value * 100          // TODO: currency specs instead of 100
//            print("intValue: \(Int(value)) \(currency.noteBase)")
            return Int(value)
        }
    }
    return 0
}
// MARK: -
struct OIMamountV: View {
    let amount: Amount?
    let currStr: String

    var body: some View {
        HStack {
            Spacer()
            if let amount {
                let amountVal = intValue(amount)
                AmountV(currStr, cent: UInt64(amountVal), isNegative: nil)
                    .foregroundColor(WalletColors().attention)  // talerColor)
#if DEBUG
                    .onTapGesture {
                        debugAnimations.toggle()
                    }
#endif
            }
        }.padding(.horizontal, UIScreen.hasFaceID ? 20 : 4)
        .ignoresSafeArea(edges: .all)
    }
}
// MARK: -
struct OIMbackground<Content: View>: View {
    let amount: Amount?
    let currStr: String
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
            OIMamountV(amount: amount, currStr: currStr)
        }
        if #available(iOS 16.4, *) {
            zStack
                .toolbar(.hidden, for: .navigationBar, .tabBar)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {        // Fallback on earlier versions
            zStack
//                .navigationBarTitle("")       // must set the title before you can hide the navigation bar
                .navigationBarHidden(true)
//                .tabBarHidden(true)           // unfortunately this call doesn't exist
        }
    }
}
// MARK: -
struct OIMnavBack<Content: View>: View {
    let stack: CallStack
    let scope: ScopeInfo?
    let currStr: String
    @Binding var amount: Amount
    @Binding var buttonSelected: Bool
    var content: () -> Content

    @Environment(\.dismiss) var dismiss     // call dismiss() to pop back

    var body: some View {
        OIMbackground(amount: amount, currStr: currStr) {
            ZStack {
                content()
                VStack {
                    HStack {
                        BackButton() {
                            print("dismiss")
                            dismiss()
                        }.padding(.leading, 4)
                        Spacer()
                        let inset = UIScreen.horzInsets
                        ForwardButton(enabled: !amount.isZero) {
                            buttonSelected = true
                        }.padding(.trailing, inset > 0 ? inset - 12 : 0)
                    }
                }
                .ignoresSafeArea(edges: .horizontal)
            }
        }
    }
}

// MARK: -
struct OIMView: View {
    let stack: CallStack
    let scope: ScopeInfo?
    let amount: Amount?
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var qrButtonTapped: Bool

    @AppStorage("sierraLeone") var sierraLeone: Bool = false

    @State private var amountVal: Int = 0
    @Namespace var namespace
    @State private var tappedVal = 0
    @State private var flying = 0
    @State private var shake = false

    var body: some View {
//        let _ = Self._printChanges()
        let currency = sierraLeone ? OIMleones : OIMeuros

        let actions = HStack(spacing: 30) {
            QRButton(isNavBarItem: false) {
                qrButtonTapped = true
            }
            .lineLimit(5)
            .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .center))

            SendRequestV(stack: stack.push(),
                  sendDisabled: false,
                  recvDisabled: false)
        }

        OIMbackground(amount: amount, currStr: currency.noteBase) {
            VStack {
                Spacer()
                OIMlineView(currency: currency,
                           amountVal: $amountVal,
                           tappedVal: tappedVal,
                              flying: $flying,
                               shake: shake,
                             canEdit: false)
                Spacer()
                actions
            }//.border(.red)
        }.task {
            amountVal = intValue(amount)
        }
    }
}
// MARK: -
struct OIMPayView: View {
    let stack: CallStack
    let scope: ScopeInfo?
    let amount: Amount?
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)

    @AppStorage("sierraLeone") var sierraLeone: Bool = false

    @State private var amountVal: Int = 0
    @Namespace var namespace
    @State private var tappedVal = 0
    @State private var flying = 0
    @State private var shake = false

    var body: some View {
//        let _ = Self._printChanges()
        let currency = sierraLeone ? OIMleones : OIMeuros

        OIMbackground(amount: amount, currStr: currency.noteBase) {
            VStack {
                Spacer()
                OIMlineView(currency: currency,
                           amountVal: $amountVal,
                           tappedVal: tappedVal,
                              flying: $flying,
                               shake: shake,
                             canEdit: true)
                Spacer()
            }.border(.red)
        }.task {
            amountVal = intValue(amount)
        }

    }
}
// MARK: -
struct OIMEditView: View {
    let stack: CallStack
    let scope: ScopeInfo?
    @Binding var amount: Amount
    @Binding var available: Amount
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var buttonSelected: Bool

    @AppStorage("sierraLeone") var sierraLeone: Bool = false

    @State private var amountVal: Int = 0
    @State private var availableVal: Int = 0

    @Namespace var namespace
    @State private var tappedVal = 0
    @State private var flying = 0
    @State private var shake = false

    var body: some View {
//        let _ = Self._printChanges()
        let currency = sierraLeone ? OIMleones : OIMeuros

        OIMnavBack(stack: stack.push(),
                   scope: scope,
                 currStr: currency.noteBase,
                  amount: $amount,
          buttonSelected: $buttonSelected
        ) {
            ZStack {    // without this, money would fly below the scroller
              VStack {  // even though this is the only item in the ZStack
                Spacer()
                OIMlineView(currency: currency,
                           amountVal: $amountVal,
                           tappedVal: tappedVal,
                              flying: $flying,
                               shake: shake,
                             canEdit: true)
                    .zIndex(1)  // make notes fly from topZ
                    .onChange(of: amountVal) { newVal in
                        let currencyStr = amount.currencyStr
                        amount = Amount(currency: currencyStr, cent: UInt64(newVal))
                        availableVal = intValue(available) - intValue(amount)
                    }
                Spacer()
                OIMcurrencyScroller(currency: currency,
                                availableVal: $availableVal,
                                   amountVal: $amountVal,
                                   tappedVal: $tappedVal,
                                      flying: $flying,
                                       shake: $shake)
                    .onChange(of: available) { newVal in
                        availableVal = intValue(newVal) - intValue(amount)
                    }
              }
                .border(.red)
            }
        }.task {
            amountVal = intValue(amount)
            availableVal = intValue(available) - intValue(amount)
        }
    }
}
// MARK: -
struct OIMSubjectView: View {
    let stack: CallStack
    let scope: ScopeInfo?
    @Binding var amount: Amount
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var buttonSelected: Bool

    @AppStorage("sierraLeone") var sierraLeone: Bool = false

    var body: some View {
//        let _ = Self._printChanges()
        let currency = sierraLeone ? OIMleones : OIMeuros

        OIMnavBack(stack: stack.push(),
                   scope: scope,
                 currStr: currency.noteBase,
                  amount: $amount,
          buttonSelected: $buttonSelected
        ) {
            VStack {
                Spacer()
                HStack {
                    Text("Subject")
                }
                Spacer()
            }.border(.red)
        }.task {

        }

    }
}



// MARK: -
//#Preview {
//    OIMView()
//}
