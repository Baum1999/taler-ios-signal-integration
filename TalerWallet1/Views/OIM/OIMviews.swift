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

let OIMACTION = "OIMaction"
let OIMACTION2 = "OIMaction2"
let OIMNUMBER = "OIMnumber"
let OIMCHEST = "OIMchest"
let OIMBACK = "OIMback"
let OIMSIDE = "OIMside"

// MARK: -
struct OIMnavBack<Content: View>: View {
    let stack: CallStack
    let currencyName: String
    let chest: String
    let isFinal: Bool                   // bordered action button
    let isSending: Bool                 // move action button
    let amount: Amount?
    let action: (() -> Void)?
    var content: () -> Content

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        OIMbackground() {
            ZStack(alignment: .top) {
                content()
                VStack {
                    HStack {
                        OIMbalanceButton(isOpen: true, chest: chest, isFinal: false) {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                dismiss()
                            }
                        }
                            .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                        Spacer()
                        let amountIsZero = amount?.isZero ?? true
                        OIMactionButton(type: .sendP2P,
                                     isFinal: isFinal,
                                      action: amountIsZero ? nil : action)
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
                .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                .disabled(true)
                .opacity(INVISIBLE)
                .matchedGeometryEffect(id: OIMNUMBER, in: wrapper.namespace, isSource: true)
                .accessibilityHidden(true)

            if history {
                Spacer()
            }
            // balance
            OIMamountV(amount: amount, currencyName: cash.currency.currencyStr)
            if !history {
                if let secondAmount {
                    Spacer()
                    // amountToSend
                    OIMamountV(amount: secondAmount, currencyName: cash.currency.currencyStr)
                }
                // invisible - source for money (target) flying out of and back in the open chest
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
