/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

let MAXSTACK = 4

enum FundState: Int {
    case idle
    case shouldFly
    case isFlying
    case flipped
}

/// data structure for a cash item on the table
public struct OIMfund: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int                  // support multiple funds with the same value
    let value: UInt64
    var state: FundState

    var targetID: String {
        String(state == .shouldFly ? -Int(value)        // match sourceID
                                   : id)
    }
}
public typealias OIMfunds = [OIMfund]

// MARK: -
class OIMcash: ObservableObject {
    var ticker = 0                  // increment each time a fund is added (or melted from others)
    var currency: OIMcurrency
    @Published var funds: OIMfunds = []

    @AppStorage("sierraLeone") var sierraLeone: Bool = false

    init(_ currency: OIMcurrency? = nil) {
        if let currency {
            self.currency = currency
        } else {
            self.currency = OIMeuros
        }
        if sierraLeone {
            self.currency = OIMleones
        }
    }

    func sortByValue() -> OIMfunds {
        // sorts ASCENDING - we check small values first
        funds.sorted(by: { ($0.value < $1.value) ||
            ( ($0.value == $1.value) && ($0.id > $1.id) ) })
    }

    func checkStacks(first firstCheck: UInt64, _ max: Int = MAXSTACK) -> UInt64? {
        /// same algorithm as OIMlayout.computeSpaces
        /// result is 0 if all stacks have 4 or less items
        /// returns highest value with more than 4 items

        let sorted = sortByValue()
        let count = sorted.count

        var stackIndex = 0
        var lastValue: UInt64 = 0
        for (index, fund) in sorted.enumerated() {
            let value = fund.value
            let state = fund.state
            if state == .shouldFly || state == .isFlying {  // flying can not go on the stack
                lastValue = 0                               // let the next subview...
                stackIndex = 0                              // ...start a new stack
            } else if lastValue != value {                  // different value?
                lastValue = value                           // save this value for the next subview
                stackIndex = 0                              // start a new stack
            } else {
                stackIndex += 1                             // Yay, we found one to add to this stack
                if stackIndex == max {                      // stack is full
                    return value        // <<= compact this stack
            }   }
        }
        return nil
    }

    func convert(_ nr: UInt64, of stackValue: UInt64, to biggerDenom: UInt64) -> Bool {
        let sorted = sortByValue()
        var counter = nr
        var toDelete: OIMfunds = []
        var amount: UInt64 = 0
        for var fund in sorted {
            if fund.value == stackValue && counter > 0 {
                withAnimation(.basic1) {
                    fund.state = .flipped
                    updateFund(fund)
                }
                toDelete.append(fund)
                counter -= 1
                amount += stackValue
            }
        }
        DispatchQueue.main.async {
            withAnimation(.remove1) {
                for fund in toDelete {
                    self.removeCash(id: fund.id, value: fund.value)
                }
            }
            withAnimation(.basic1) {
                while amount >= biggerDenom {
                    self.addCash(value: biggerDenom, .flipped)
                    amount -= biggerDenom
                }
            }
            if amount > 0 {
                print("  ❗️Yikes: convert failed", amount)
            }
        }
        return counter == 0
    }

    func compactStacks(_ value: UInt64) -> Bool {
        let denominations = currency.bankNotes + currency.bankCoins
        if let index = denominations.firstIndex(where: { $0 == value }) {
            if index > 0 {                                  // does a bigger denomination exist?
                let value5x = value * 5
                let nextIndex = index-1
                let nextValue = denominations[nextIndex]    // let next = next_bigger_denomination
                if nextValue == value5x {
                    return convert(5, of: value, to: nextValue)
                }
                // since we want to "convert" adjacent denominations (some smaller will become 1 larger fund),
                // we cannot use the whole 5 smaller funds (4 in stack, 1 just added) if next is not 5 times bigger
                // check whether there are any items of next already on the table
                let hasNextIdx = funds.firstIndex(where: { $0.value == nextValue })
                if hasNextIdx == nil {                      // no, then...
                    if index > 1 {                          // check the second bigger denomination
                        let secondIdx = index-2
                        let secondValue = denominations[secondIdx]
                        if secondValue <= value5x && secondValue.isMultiple(of: value) {
                            let nrToDelete = secondValue / value
                            return convert(nrToDelete, of: value, to: secondValue)
                        }
                    }
                }
                // If we arrive here, either there is no second denomination any more, or it is not a multiple of value,
                // or there are already some funds of next on the table
                if nextValue.isMultiple(of: value) {
                    let nrToDelete = nextValue / value
                    return convert(nrToDelete, of: value, to: nextValue)
                }
                // Now this is tricky - there are already some funds of next on the table, but next is not a multiple of value
                // But maybe 2 of next are a multiple - e.g. value=10, next=25
                let nextValue2x = nextValue * 2
                if nextValue2x.isMultiple(of: value) {
                    let nrToDelete = nextValue * 2 / value
                    if nrToDelete <= 5 {
                        return convert(nrToDelete, of: value, to: nextValue)    // 5*10 = 2*25
                    }
                }
            }
            // It seems we cannot merge with adjacent funds :-(
            // Or there is no "next", the user already has the highest denomination
        }
        return false
    }

    func notes() -> OIMfunds {
        let firstCoinVal = currency.bankCoins[0]
        return funds.filter { $0.value > firstCoinVal }
    }

    func coins() -> OIMfunds {
        let firstCoinVal = currency.bankCoins[0]
        return funds.filter { $0.value <= firstCoinVal }
    }

    func addCash(value: UInt64, _ newState: FundState = .shouldFly) {
        let fund = OIMfund(id: ticker, value: value, state: newState)
        ticker += 1
        funds.append(fund)
    }

    func removeCash(id: Int, value: UInt64) {
        if let index = funds.firstIndex(where: { $0.id == id && $0.value == value }) {
            funds.remove(at: index)
        } else if let index = funds.lastIndex(where: { $0.value == value && $0.state == .flipped }) {
            funds.remove(at: index)
        } else if let index = funds.firstIndex(where: { $0.value == value }) {
            funds.remove(at: index)
        }
    }

    func updateFund(_ item: OIMfund) {
        let itemID = item.id
        if let index = funds.firstIndex(where: { $0.id == itemID }) {
            funds[index] = item
        } else {
            funds = funds.map {
                $0.id == itemID ? item : $0
            }
        }
    }

    func update(_ notesCoins: OIMnotesCoins, currency: OIMcurrency) {
        let chng1 = update(notesCoins.0, currencyNotesCoins: currency.bankNotes)
        let chng2 = update(notesCoins.1, currencyNotesCoins: currency.bankCoins)
    }

    func update(_ notesCoins: OIMdenominations, currencyNotesCoins: OIMdenominations) -> Bool {
        var array = funds
        var changed = false
        for (index, value) in currencyNotesCoins.enumerated() {
            let wanted = notesCoins[index]      // number of notes which should be shown
            var shownNotes = array.filter { $0.value == value }
            var count = shownNotes.count
            while count > wanted {
                let note = shownNotes[0]
                print("update: remove \(note.value)")
                if let index = array.firstIndex(of: note) {
                    array.remove(at: index)
                    changed = true
                }
                shownNotes.remove(at: 0)
                count -= 1
            }
            while count < wanted {
                let note = OIMfund(id: ticker, value: value, state: .idle)
                ticker += 1
                print("update: add \(note.value)")
                array.append(note)
                changed = true
                count += 1
            }
        }
        if changed {
            funds = array
        }
        return changed
    }
}
