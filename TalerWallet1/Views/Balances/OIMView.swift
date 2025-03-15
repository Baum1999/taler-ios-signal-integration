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
/// renders 1 banknote from a currency with size/4
struct OIMnoteV: View {
    let value: Int
    let currency: OIMcurrency

    var body: some View {
        if let name = currency.noteName(value) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: currency.noteWidth / 4, height: currency.noteHeight / 4)
                .accessibilityLabel(Text("\(value)", comment: "VoiceOver"))
        } else {
            EmptyView()
        }
    }
}

/// renders 1 coin from a currency with size/4
struct OIMcoinV: View {
    let value: Int
    let currency: OIMcurrency

    var body: some View {
        if let name = currency.coinName(value), let size = currency.coinSize(value) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size / 4, height: size / 4)
                .accessibilityLabel(Text("\(value)", comment: "VoiceOver"))
        } else {
            EmptyView()
        }
    }
}

/// renders 1 denomination from a currency
struct OIMsingleV: View {
    let value: Int
    let currency: OIMcurrency

    var body: some View {
        if value > currency.bankCoins[0] {
            OIMnoteV(value: value, currency: currency)
        } else {
            OIMcoinV(value: value, currency: currency)
        }
    }
}

// MARK: -
// renders a stack of (identical) banknotes with offset 20
struct OIMnoteStackV: View {
    let value: Int
    let count: Int
    let currency: OIMcurrency

    var body: some View {
        let offset = 20
        let maxIndex = count - 1
        ZStack {
            ForEach(0...maxIndex, id: \.self) { index in
                OIMnoteV(value: value, currency: currency)
                    .offset(x: CGFloat(offset * index), y: CGFloat(offset * index))
            }
        }
        .padding(.trailing, CGFloat(offset * maxIndex))
        .padding(.bottom, CGFloat(offset * maxIndex))
    }
}

// renders a stack of (identical) coins with offset size/16
struct OIMcoinStackV: View {
    let value: Int
    let count: Int
    let currency: OIMcurrency

    var body: some View {
        let number = count - 1
//        let _ = print("CoinStack: \(count) * \(value) \(currency.coinBase)")
        if let size = currency.coinSize(value) {
            let offset = size / 16
            ZStack {
                ForEach(0...number, id: \.self) { index in
                    OIMcoinV(value: value, currency: currency)
                        .offset(x: offset * CGFloat(index), y: offset * CGFloat(index))
                }
            }
//#if DEBUG
//            .border(Color.red)
//#endif
            .padding(.trailing, offset * CGFloat(number))
            .padding(.bottom, offset * CGFloat(number))
//#if DEBUG
//            .border(Color.green)
//#endif
        }
    }
}

// renders a stack of 1 denomination
struct OIMstackV: View {
    let value: Int
    let count: Int
    let currency: OIMcurrency

    var body: some View {
        if value > currency.bankCoins[0] {
            OIMnoteStackV(value: value, count: count, currency: currency)
        } else {
            OIMcoinStackV(value: value, count: count, currency: currency)
        }
    }
}

// MARK: -
// renders a spread of banknote-stacks in 1 row
struct OIMnotesView1: View {
    let spread: OIMdenominations
    let currency: OIMcurrency
    @Binding var amount: Int

    var body: some View {
        let nrOfNotes = currency.bankNotes.count - 1
        HStack(alignment: .top, spacing: 10) {
            ForEach(0...nrOfNotes, id: \.self) { index in
                let count = spread[index]
                if count > 0 {
                    let value = currency.bankNotes[index]
                    OIMnoteStackV(value: value, count: count, currency: currency)
                        .onTapGesture {
                            withAnimation(Animation.easeIn(duration: 0.25)) {
                                amount -= value
                            }
                        }
                }
            }
        }
    }
}

// renders a spread of coin-stacks in 1 row
struct OIMcoinsView1: View {
    let spread: OIMdenominations
    let currency: OIMcurrency
    @Binding var amount: Int

    var body: some View {
        let nrOfCoins = currency.bankCoins.count - 1
        HStack(alignment: .top, spacing: 10) {
            ForEach(0...nrOfCoins, id: \.self) { index in
                let count = spread[index]
                if count > 0 {
                    let value = currency.bankCoins[index]
                    OIMcoinStackV(value: value, count: count, currency: currency)
                        .onTapGesture {
                            withAnimation(Animation.easeIn(duration: 0.25)) {
                                amount -= value
                            }
                        }
                }
            }
        }
    }
}

// MARK: -

// renders all banknotes and coins in 1 horizontal scrollview
struct OIMcurrencyScroller: View {
    let currency: OIMcurrency
    @Binding var amount: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(currency.bankNotes, id: \.self) { value in
                    OIMnoteV(value: value, currency: currency)
                        .onTapGesture {
                            withAnimation(Animation.easeIn(duration: 0.25)) {
                                amount += value
                            }
                        }
                }
                ForEach(currency.bankCoins, id: \.self) { value in
                    OIMcoinV(value: value, currency: currency)
                        .onTapGesture {
                            withAnimation(Animation.easeIn(duration: 0.25)) {
                                amount += value
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
    let balance: Balance?
    let currency: OIMcurrency
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("oimTwoRows") var oimTwoRows: Bool = false

    @State private var banknotes: Columns = []
    @State private var integerCoins: Columns = []
    @State private var fractalCoins: Columns = []

    @State private var amount: Int = 0

    var intValue: Int {
        if let balance {
            let amount = balance.available
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
                    let result = currency.notesCoins(amount)
                    // Text("notes: \(result.0), coins: \(result.1)")
                    OIMnotesView1(spread: result.0, currency: currency, amount: $amount)
                        .padding(.trailing, 20)
                    OIMcoinsView1(spread: result.1, currency: currency, amount: $amount)
                }
            }
                .task {
                    amount = intValue
//                    amount = 14983
                }

            Spacer()
            OIMcurrencyScroller(currency: currency, amount: $amount)
                .onChange(of: amount) { newValue in
//                    print("new Amount: \(newValue)")
                    let result = currency.notesCoins(newValue)
                    buildColumns(result, currency: currency)
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

/// https://stackoverflow.com/questions/57132417/swiftui-scrollview-is-not-able-to-disable-vertical-bounce
extension View {
    @ViewBuilder
    func viewExtractor(result: @escaping (UIView) -> ()) -> some View {
        self
            .background(ViewExtractorHelper(result: result))
            .compositingGroup()
    }
}

fileprivate struct ViewExtractorHelper: UIViewRepresentable {
    var result: (UIView) -> ()

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let superView = view.superview?.superview?.subviews.last?.subviews.first {
                result(superView)
            }
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {

    }
}

//#Preview {
//    OIMView()
//}
