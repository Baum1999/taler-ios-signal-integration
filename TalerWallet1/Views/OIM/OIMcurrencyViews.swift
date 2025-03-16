/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

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


//#Preview {
//    OIMView()
//}
