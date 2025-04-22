/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import os.log
import SymLog

let MAXSTACK = 4

enum FundState: Int {
    case idle
    case returning           // user tapped to remove

    case shouldFly          // + button tapped
    case isFlying           // after onAppear

    case position           // position to move to
    case moving             // move to position
    case hiding             // hide at position
    case morphing           // flip
    case arriving           // keep flipped image, move to final position
    case mutating           // flip back with disbled transition

    var returning: Bool { self == .returning }
    var shouldFly: Bool { self == .shouldFly }
    var isFlying: Bool { self == .isFlying }
    var position: Bool { self == .position }
    var morphing: Bool { self == .morphing }
    var moving: Bool { self == .moving }
    var hiding: Bool { self == .hiding }
    var mutating: Bool { self == .mutating }
}

/// data structure for a cash item on the table
public struct OIMfund: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int                  // support multiple funds with the same value
    var state: FundState
    var value: UInt64                   // can be morphed
    var morphTicker: Int?               // `semaphore´ to reserve a fund - don't morph this twice concurrently
    var flippedVal: UInt64?             // the value to morph into - layout.sortByValue will take this instead of value
    var outValue: UInt64?               // if this is set it determines the image (used for flipping)

    var targetID: String {
        String(state.shouldFly || state.returning ? -Int(value)        // match sourceID
                                                  : id)
    }
    var shouldFly: Bool { state.shouldFly }
    var isFlying: Bool { state.isFlying }
//    var isFlipping: Bool { state.flipping }

}
public typealias OIMfunds = [OIMfund]

// MARK: -
final class OIMcash: ObservableObject, Sendable {
    private let symLog = SymLogV(0)
    let logger = Logger(subsystem: "net.taler.gnu", category: "OIMcash")
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

    var delay: Double {
#if DEBUG
        if debugAnimations { return 5.0 }
//        return fastAnimations ? 5 : 1.0
#endif
        return fastAnimations ? 0.4 : 0.8
    }


    func sortByValue() -> OIMfunds {
        /// sorts ASCENDING but keeps the order of the IDs for identical values
        funds.sorted(by: {
            ($0.value < $1.value) ||
           (($0.value == $1.value) && ($0.id > $1.id))
        })
    }

    func checkStacks(first firstCheck: UInt64, _ max: Int = MAXSTACK) -> UInt64? {
        let sorted = sortByValue()
        /// same algorithm as OIMlayout.computeSpaces
        /// result is 0 if all stacks have 4 or less items
        /// returns lowest fund.value with more than 4 items

        var stackIndex = 0
        var lastValue: UInt64 = 0
        for fund in sorted {
            let value = fund.value
            let state = fund.state
            if fund.shouldFly || fund.isFlying      {  // flying can not go on the stack
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
//MARK: -
    func morph(_ nr: UInt64, of outValue: UInt64, to inValue: UInt64) -> Bool {
        let morphTicker = ticker                        // capture ticker at start of morphing
        symLog.log("  Start morphing #\(morphTicker)")
        let sorted = sortByValue()
        var toDelete: OIMfunds = []

        var amount: UInt64 = 0                          // ensure sum(morphedOut) is sum(morphedIn)
        var counter = nr                                // counts outValues to be morphed
        var added = 0                                   // counts inValues to be morphed
        var first = true
        for var fund in sorted {                        // remove newest funds first
            if fund.value == outValue && fund.morphTicker == nil && counter > 0 {
                fund.morphTicker = first ? morphTicker : -morphTicker
                first = false
                updateFund(fund)
                toDelete.append(fund)
                counter -= 1
                amount += outValue
            }
        }
        if counter > 0 {
            logger.warning("  ❗️Yikes: didn't find \(nr) funds to morph, missing \(counter)")
        }

        while amount >= inValue {
            amount -= inValue
            added += 1          // TODO: If we added more than 1, then we must morph more
        }
        if amount > 0 {
            logger.warning("  ❗️Yikes: morph leftover:\(amount)")
        }

        /// Stage 1: the fund with the highest id just got added - that is the anchor position for the morph
        var morphFund = toDelete.removeFirst()
        added -= 1
        symLog.log(">>taking this anchor \(morphFund.id) \(morphFund.value) \(morphFund.state.rawValue)")
        withAnimation(.basic1) {
            morphFund.outValue = outValue               // save old image
            morphFund.flippedVal = inValue              // layout.sortByValue will take this instead of value
            morphFund.state = .position                 // to compute the position where the morph happens
            updateFund(morphFund)
        }
        withAnimation(.easeInOutDelay2) {
            symLog.log(">>moving outgoing to \(morphFund.id) \(morphFund.value) \(morphFund.state.rawValue)")
            for var delFund in toDelete {               // move the rest of the leaving funds
                delFund.state = .moving                 // to the morphing position
                updateFund(delFund)
            }
        }

        /// Stage 2: After arriving at the position, without animation hide all outValues (except our anchor)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for var delFund in toDelete {
                self.symLog.log(">>hide \(delFund.id)")
                delFund.state = .hiding                 // make invisible
                self.updateFund(delFund)                // TODO: check if stack remains!!!
            }

            /// Stage 3: flip animated
            morphFund.state = .morphing
            self.symLog.log(">>flip \(morphFund.id), \(morphFund.value) \(morphFund.state.rawValue)")
            self.updateFund(morphFund)  // withAnimation not needed, it animates itself when flipping
            self.symLog.log(">>flipped \(morphFund.id) \(morphFund.value) \(morphFund.state.rawValue)")

            /// Stage 4: move inValues to final position, delete outValues from funds array
            DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                morphFund.state = .arriving
                morphFund.value = inValue                       // stack position
                morphFund.morphTicker = nil                     // release `semaphore´
                self.symLog.log(">>move to final position \(morphFund.id) \(morphFund.state.rawValue)")
                withAnimation(.move1) {
                    self.updateFund(morphFund)
                    while added > 0 {
                        var fund = toDelete.removeFirst()
                        fund.value = inValue                    // transmute to inValue (without flip)
                        fund.morphTicker = nil                  // release `semaphore´
                        fund.state = .idle                      // move to their positions
                        self.updateFund(fund)
                        added -= 1
                    }
                    // remaining outValues were already invisible, but we need to animate the stack they came from
                    for var delFund in toDelete {
                        self.symLog.log(">>remove \(delFund.id)")
                        self.removeCash(id: delFund.id, value: delFund.value)
                    }
                }

                /// Stage 5: transmute morphFund
                DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                    morphFund.state = .mutating
//                    morphFund.state = .idle
                    morphFund.outValue = nil
                    morphFund.flippedVal = nil
                    self.symLog.log(">>transmute \(morphFund.id) \(morphFund.value) \(morphFund.state.rawValue)")
                    self.updateFund(morphFund)

                    /// Stage 6: back to idle
                    DispatchQueue.main.async {
                        withAnimation(.move1) {
                            morphFund.state = .idle
                            self.updateFund(morphFund)
                        }
                    }
                }

            }
        } // asyncAfter delay
        return counter == 0
    }

    func compactStacks(_ value: UInt64) -> Bool {
        symLog.log("  Start compactStacks \(value)")
        let denominations = currency.bankNotes + currency.bankCoins
        if let index = denominations.firstIndex(where: { $0 == value }) {
            if index > 0 {                                  // does a bigger denomination exist?
                let value5x = value * 5
                let nextIndex = index-1
                let nextValue = denominations[nextIndex]    // let next = next_bigger_denomination
                if nextValue == value5x {
                    return morph(5, of: value, to: nextValue)
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
                            return morph(nrToDelete, of: value, to: secondValue)
                        }
                    }
                }
                // If we arrive here, either there is no second denomination any more, or it is not a multiple of value,
                // or there are already some funds of next on the table
                if nextValue.isMultiple(of: value) {
                    let nrToDelete = nextValue / value
                    return morph(nrToDelete, of: value, to: nextValue)
                }
                // Now this is tricky - there are already some funds of next on the table, but next is not a multiple of value
                // But maybe 2 of next are a multiple - e.g. value=10, next=25
                let nextValue2x = nextValue * 2
                if nextValue2x.isMultiple(of: value) {
                    let nrToDelete = nextValue * 2 / value
                    if nrToDelete <= 5 {
                        return morph(nrToDelete, of: value, to: nextValue)    // 5*10 = 2*25
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

    func addCash(value: UInt64, _ newState: FundState = .shouldFly, _ flippedVal: UInt64? = nil) -> OIMfund {
        let fund = OIMfund(id: ticker, state: newState, value: value, flippedVal: flippedVal)
        ticker += 1
        symLog.log(">>adding \(value) \(fund.id)")
        funds.append(fund)
        return fund
    }

    func removeCash(id: Int, value: UInt64) {
        if let index = funds.firstIndex(where: { $0.id == id && $0.value == value }) {
            funds.remove(at: index)
        } else if let index = funds.lastIndex(where: { $0.value == value && $0.state.returning }) {
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

    func moveDown() -> Double {
        let sorted = sortByValue()

        var counter = 0.0
        var lastVal: UInt64 = 0
        for var fund in sorted {
            withAnimation(.easeOut1.delay(counter * 0.1)) {
                fund.state = .returning
                self.updateFund(fund)
            }
            if lastVal != fund.value {
                lastVal = fund.value
                counter += 1
            }
        }
        return counter * 0.1
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
                symLog.log("update: remove \(note.value)")
                if let index = array.firstIndex(of: note) {
                    array.remove(at: index)
                    changed = true
                }
                shownNotes.remove(at: 0)
                count -= 1
            }
            while count < wanted {
                let note = OIMfund(id: ticker, state: .idle, value: value, flippedVal: nil)
                ticker += 1
                symLog.log("update: add \(note.value)")
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
