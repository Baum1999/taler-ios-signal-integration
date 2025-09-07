/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

let OIMbuttonSize = 80.0
let OIMactionSize = 120.0

let OIMACTION = "OIMaction"         // Position: trailing edge of the title row
let OIMACTION2 = "OIMaction2"       // currently unused
let OIMNUMBER = "OIMnumber"
let OIMCHEST = "OIMchest"
let OIMBACK = "OIMback"
let OIMSIDE = "OIMside"

// MARK: -
struct OIMnavBack<Content: View>: View {
    let stack: CallStack
    let chest: String
    let type: OIMactions
    let isFinal: Bool                   // bordered action button
    let isSending: Bool                 // move action button
    let action: (() -> Void)?
    let actDisabled: Bool
    var content: () -> Content

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        OIMbackground() {
            ZStack(alignment: .top) {
                content()
                VStack {
                    HStack {    // top: chest <-> action
                        OIMbalanceButton(isOpen: true, chest: chest, isFinal: false) {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true           // doesn't work with NavigationView
                            withTransaction(transaction) {
                                dismiss()
                            }
//                            withAnimation(nil) {  doesn't work either
//                                dismiss()
//                            }
                        }
                            .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                        Spacer()
                        OIMactionButton(type: type,
                                     isFinal: isFinal,
                                      action: actDisabled ? nil : action)
                            .frame(width: OIMactionSize, height: OIMbuttonSize)
                            .matchedGeometryEffect(id: isSending ? OIMACTION : OIMACTION2,
                                                   in: wrapper.namespace, isSource: false)
                    }
                }
//                .border(.blue)
            }
        }
    }
}
// MARK: -
struct OIMtitleView: View {
    let cash: OIMcash
    let amount: Amount?
    let history: Bool
    let secondAmount: Amount?

    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        let chest = cash.currency.chest
        HStack(alignment: .top) {
            // invisible - source where the selected balance chest (target) moves to
            OIMbalanceButton(isOpen: true, chest: chest, isFinal: false) {}
                .frame(width: OIMbuttonSize, height: history ? OIMbuttonSize / 2 : OIMbuttonSize)
                .disabled(true)
                .opacity(INVISIBLE)
                .matchedGeometryEffect(id: OIMNUMBER, in: wrapper.namespace, isSource: true)
                .accessibilityHidden(true)
//                .border(.red)
            if history {
                Spacer()
            }
            // balance
            OIMamountV(amount: amount, currencyName: cash.currency.currencyStr, factor: cash.currency.factor)
            if !history {
                if let secondAmount {
                    Spacer()
                    // amountToSend
                    OIMamountV(amount: secondAmount, currencyName: cash.currency.currencyStr, factor: cash.currency.factor)
                }
                // invisible - source for money (target) flying out of and back in the open chest
                // Position: trailing edge of the title row
                OIMactionButton(type: .sendP2P, isFinal: false, action: nil)
                    .frame(width: OIMactionSize, height: OIMbuttonSize)
                    .disabled(true)
                    .opacity(INVISIBLE)
                    .matchedGeometryEffect(id: OIMACTION, in: wrapper.namespace, isSource: true)
                    .accessibilityHidden(true)
            }
        }
    }
}
