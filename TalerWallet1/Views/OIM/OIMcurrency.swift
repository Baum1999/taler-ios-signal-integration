/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

public typealias OIMdenominations = [UInt64]
public typealias OIMnotesCoins = (OIMdenominations, OIMdenominations)       // number of notes and coins

// 6 banknotes, 8 coins of which 6 are fractionals < 100
public let OIMeuros  = OIMcurrency(bankNotes: [20000, 10000, 5000, 2000, 1000, 500],
                                   bankCoins: [200, 100,  50,  20,  10,   5,   2,   1],
                                   coinSizes: [258, 232, 242, 222, 198, 212, 188, 162],
                                    noteBase: "EUR", coinBase: "eur")

// 3 stacks, 5 banknotes, 5 coins (all fractionals)
public let OIMleones = OIMcurrency(bankNotes: [ 10000, 2000, 1000, 500, 200, 100],
                                   bankCoins: [ 50,  10,   5,   1],
                                   coinSizes: [270, 240, 228, 208],
                                   // [ 260mm 270px, 240mm 250px, 230mm 240px, 225mm 228px, 200mm 208px]
                                    noteBase: "SLE", coinBase: "sle")

// 6 banknotes, 6 coins of which 5 are fractionals < 100
public let OIMdollars = OIMcurrency(bankNotes: [10000, 5000, 2000, 1000, 500, 200],          // XXX x 265
                                    bankCoins: [100,  50,  25,  10,   5,   1],
                                    coinSizes: [265, 306, 243, 180, 212, 190],
                                     noteBase: "USD", coinBase: "usd")
// MARK: -
public struct OIMcurrency: Sendable {
    let bankNotes: OIMdenominations             // values of each banknote, in cents, descending
    let bankCoins: OIMdenominations             // values of each coin
    let coinSizes: [CGFloat]                    // coin sizes
    let noteBase: String
    let coinBase: String

    func coinSize(_ value: UInt64) -> CGFloat? {
        for (index, element) in bankCoins.enumerated() {
            if element == value {
                if index < coinSizes.count {
                    return coinSizes[index]
                }
            }
        }
        return nil
    }

    func coinName(_ value: UInt64) -> String? {
        if bankCoins.contains(value) {
            return coinBase + "-" + String(value)
        }
        return nil
    }

    func noteName(_ value: UInt64) -> String? {
        if bankNotes.contains(value) {
            return noteBase + "-" + String(value)
        }
        return nil
    }

    /// spreads out the input value into banknotes and coins of the currency
    func notesCoins(_ intVal: UInt64) -> OIMnotesCoins {
        var notes: OIMdenominations = []
        var coins: OIMdenominations = []

        var value = intVal
        for (index, element) in bankNotes.enumerated() {
            var count: UInt64 = 0
            while value >= element {
                value = value - element
                count += 1
            }
            notes.append(count)
        }

        for (index, element) in bankCoins.enumerated() {
            var count: UInt64 = 0
            while value >= element {
                value = value - element
                count += 1
            }
            coins.append(count)
        }
        return (notes, coins)
    }
}

