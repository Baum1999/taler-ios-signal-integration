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

// MARK: -

// renders all banknotes and coins in 1 horizontal scrollview
struct OIMcurrencyScroller: View {
    let currency: OIMcurrency
    @Binding var amountVal: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(currency.bankNotes, id: \.self) { value in
                    OIMnoteV(value: value, currency: currency)
                        .onTapGesture {
                            withAnimation(Animation.easeIn(duration: 0.25)) {
                                amountVal += value
                            }
                        }
                }
                ForEach(currency.bankCoins, id: \.self) { value in
                    OIMcoinV(value: value, currency: currency)
                        .onTapGesture {
                            withAnimation(Animation.easeIn(duration: 0.25)) {
                                amountVal += value
                            }
                        }
                }
            }
        }
        .viewExtractor { view in
            if let scrollView = view as? UIScrollView {
                if #available(iOS 17.4, *) {
                    scrollView.bouncesVertically = false
                } else {    // Fallback on earlier versions
                    scrollView.bounces = false
                }
            }
        }
        .padding(.bottom, 20)
        .padding(.horizontal, 8)
    }
}

// MARK: -
// renders a spread of banknote-stacks in 2 rows
struct NotesView2: View {
    let spread: OIMdenominations
    let currency: OIMcurrency

    func countVal(index: Int) -> (Int, Int)? {
        let nrOfNotes = currency.bankNotes.count - 1
        if index < nrOfNotes {
            let count = spread[index]
            if count > 0 {
                let value = currency.bankNotes[index]
                return (value, count)
            }
        }
        return nil
    }


    var body: some View {
        HStack(alignment: .top, spacing: 10) {
//            let top0: Bool
//            if let cv0 = countVal(index: 0) {
//                if cv0.1 > 1 {  //
//                    NoteStackV(value: cv0.0, count: cv0.1, currency: currency)
//                    top0 = false
//                } else {
//                    NoteStackV(value: cv0.0, count: cv0.1, currency: currency)
//                    top0 = true
//                }
//            } else {
//                top0 = false
//            }
//            if let cv1 = countVal(index: 1) {
//
//            }
        }
    }
}

// MARK: -
struct Column: Hashable {
    let topCount: Int
    let topVal: Int
    let botVal: Int
}

typealias Columns = [Column]

struct ColumnView: View {
    let column: Column
    let currency: OIMcurrency

    var body: some View {
        VStack {
            if column.topCount > 1 {
//                let _ = print("Stack: \(column.topCount) * \(column.topVal) \(currency.noteBase)")
                OIMstackV(value: column.topVal, count: column.topCount, currency: currency)
            } else {
//                let _ = print("Single: \(column.topVal) and \(column.botVal) \(currency.noteBase)")
                OIMsingleV(value: column.topVal, currency: currency)
                if column.botVal > 0 {
                    OIMsingleV(value: column.botVal, currency: currency)
                }
            }
        }
    }
}

struct OIMView: View {
    let scope: ScopeInfo?
    let amount: Amount?
    let currency: OIMcurrency
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    let canEdit: Bool

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("oimTwoRows") var oimTwoRows: Bool = false

    @State private var banknotes: Columns = []
    @State private var integerCoins: Columns = []
    @State private var fractalCoins: Columns = []

    @State private var amountVal: Int = 0

    var intValue: Int {
        if let amount {
            if !amount.isZero {
                let value = amount.value * 100          // TODO: currency specs instead of 100
//                print("intValue: \(Int(value)) \(currency.noteBase)")
                return Int(value)
            }
        }
        return 0
    }

    func buildColumns(_ spread: OIMnotesCoins, currency: OIMcurrency) {
        var topVal = 0
        var notes: Columns = []
        var intCoins: Columns = []
        var fracCoins: Columns = []

        func addTopVal(andBot: Int, to columns: inout Columns) {
            if topVal > 0 {
                columns.append(Column(topCount: 1, topVal: topVal, botVal: andBot))
//                print("add \(topVal) and \(andBot) \(currency.noteBase)")
                topVal = 0
            } else if andBot > 0 {
                topVal = andBot
            }
        }

        for (index, count) in spread.0.enumerated() {       // banknotes
            if count > 0 {
                let value = currency.bankNotes[index]
                if count > 1 {
                    if DESCENDING {
                        addTopVal(andBot: 0, to: &notes)
                    } // else fill bottom later with smaller note
                    var cnt = count
                    while cnt > 5 {
                        notes.append(Column(topCount: 5, topVal: value, botVal: 0))
                        cnt -= 5
                    }
                    notes.append(Column(topCount: cnt, topVal: value, botVal: 0))
//                    print("notes: \(count) * \(value) \(currency.noteBase)")
                } else {
                    addTopVal(andBot: value, to: &notes)
                }
            }
        }
        addTopVal(andBot: 0, to: &notes)                    // TODO: comment out to fill bottom later with coins
        banknotes = notes

        for (index, count) in spread.1.enumerated() {
            if count > 0 {
                let value = currency.bankCoins[index]
                if value > 99 {                     // TODO: use currency decimal
                    if count > 1 {
                        if DESCENDING {
                            addTopVal(andBot: 0, to: &intCoins)
                        } // else fill bottom later with smaller coin
                        intCoins.append(Column(topCount: count, topVal: value, botVal: 0))
//                        print("intCoins: \(count) * \(value) \(currency.coinBase)")
                    } else {
                        addTopVal(andBot: value, to: &intCoins)
                    }
                } else {
                    if topVal > 99 {
                        addTopVal(andBot: 0, to: &intCoins) // finish last intCoin
                    }
                    if count > 1 {
                        if DESCENDING {
                            addTopVal(andBot: 0, to: &fracCoins)
                        } // else fill bottom later with smaller coin
                        fracCoins.append(Column(topCount: count, topVal: value, botVal: 0))
//                        print("fracCoins: \(count) * \(value) \(currency.coinBase)")
                    } else {
                        addTopVal(andBot: value, to: &fracCoins)
                    }
                }
            }
        }
        if topVal > 99 {
            addTopVal(andBot: 0, to: &intCoins) // finish last intCoin
        } else {
            addTopVal(andBot: 0, to: &fracCoins)
        }
        integerCoins = intCoins
        fractalCoins = fracCoins
    }

    var body: some View {
#if PRINT_CHANGES || true
        let _ = Self._printChanges()
#endif
        let background = colorScheme == .dark ? OIMBACKDARK
                                              : OIMBACKLIGHT
        let backImage = Image(background)
            .resizable()

        let vStack = VStack {
            if let amount {
                HStack {
                    Spacer()
                    AmountV(scope, amount, isNegative: nil)
                }.padding()
            }
            Spacer()
            HStack(alignment: .top, spacing: 10) {
                if oimTwoRows {
                    ForEach(banknotes, id: \.self) { column in
                        ColumnView(column: column, currency: currency)
                    }
                    ForEach(integerCoins, id: \.self) { column in
                        ColumnView(column: column, currency: currency)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(fractalCoins, id: \.self) { column in
                            ColumnView(column: column, currency: currency)
                        }
                    } .padding(.leading, 20)
                } else {
                    OIMlineView(currency: currency, amountVal: $amountVal, canEdit: canEdit, oneLine: false)
                }
            }
                .task {
                    amountVal = intValue
//                    amount = 14983
                }

            Spacer()
            if canEdit {
                OIMcurrencyScroller(currency: currency, amountVal: $amountVal)
                    .onChange(of: amountVal) { newValue in
                        //                    print("new Amount: \(newValue)")
                        let result = currency.notesCoins(newValue)
                        buildColumns(result, currency: currency)
                    }
            }
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backImage)
            .ignoresSafeArea(edges: .all)
        if #available(iOS 16.4, *) {
            vStack
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {        // Fallback on earlier versions
            vStack
        }

    }
}

// MARK: -
//#Preview {
//    OIMView()
//}
