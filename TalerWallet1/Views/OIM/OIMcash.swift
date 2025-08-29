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
    case removing           // user tapped to remove
    case drawer

    case shouldFly          // + button tapped
    case isFlying           // after onAppear

    case chestOpening       // chest tapped, money flies out
    case reveal             // move (invisible) together with the chest to the top
    case curve              // fly out of the chest in a curve to the topRight corner
    case history            // pile up for history

    case position           // position to move to
    case moving             // move to position
    case hiding             // hide at position
    case morphing           // flip
    case arriving           // keep flipped image, move to final position
    case mutating           // flip back with disbled transition

    var removing: Bool { self == .removing }
    var drawer: Bool { self == .drawer }
    var shouldFly: Bool { self == .shouldFly }
    var isFlying: Bool { self == .isFlying || self == .reveal || self == .curve }
    var chestOpening: Bool { self == .chestOpening }
    var reveal: Bool { self == .reveal }
    var curve: Bool { self == .curve }
    var history: Bool { self == .history }
    var position: Bool { self == .position }
    var morphing: Bool { self == .morphing }
    var moving: Bool { self == .moving }
    var hiding: Bool { self == .hiding }
    var mutating: Bool { self == .mutating }
}

/// data structure for a cash item on the table
public struct OIMfund: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int                  // support multiple funds with the same value
    var value: UInt64                   // can be morphed
//    var currencyIndex: Int
    var currencyStr: String
    var state: FundState
    var delay: TimeInterval
    var morphTicker: Int?               // `semaphore´ to reserve a fund - don't morph this twice concurrently
    var flippedVal: UInt64?             // the value to morph into - layout.sortByValue will take this instead of value
    var outValue: UInt64?               // if this is set it determines the image (used for flipping)
    var targetID: String {              // match sourceID for SwiftUI animations
        let isDrawer = state.shouldFly || state.drawer || state.removing
        return state.chestOpening ? OIMCHEST + currencyStr // String(currencyIndex)
                   : state.reveal ? OIMNUMBER
                    : state.curve ? OIMACTION
                  : state.history ? OIMSIDE
                : String(isDrawer ? -Int(value)              // match currencyDrawer
                                  : id)
    }
    var shouldFly2: Bool { state.shouldFly || state.chestOpening }
    var isFlying2: Bool { state.isFlying }

    init(id: Int, value: UInt64, currencyStr: String,      // currencyIndex: Int,
         state: FundState = .idle, delay: TimeInterval = 0,
         morphTicker: Int? = nil, flippedVal: UInt64? = nil, outValue: UInt64? = nil
    ) {
        self.id = id
        self.value = value
//        self.currencyIndex = currencyIndex
        self.currencyStr = currencyStr
        self.state = state
        self.delay = delay
        self.morphTicker = morphTicker
        self.flippedVal = flippedVal
        self.outValue = outValue
    }
}
public typealias OIMfunds = [OIMfund]

// MARK: -
final class OIMcash: ObservableObject, Sendable {
    private let symLog = SymLogV(0)
    private let logger = Logger(subsystem: "net.taler.gnu", category: "OIMcash")
    private var ticker = 0                  // increment each time a fund is added (or melted from others)
//    let semaphore = AsyncSemaphore(value: 1)
    var currency: OIMcurrency
//    var currencyIndex: Int
    @Published var funds: OIMfunds = []

//    init(_ index: Int? = 0) {
//        self.currencyIndex = 0
//        self.currency = OIMeuros
//        setIndex(index)
//    }

    init(_ oimCurrency: OIMcurrency) {
        self.currency = oimCurrency
    }

    func setCurrency(_ oimCurrency: OIMcurrency) {
        self.currency = oimCurrency
    }

//    func setIndex(_ index: Int? = 0) {
//        if let index {
//            let count = OIMcurrencies.count
//            if index < count {
//                self.currencyIndex = index
//                self.currency = OIMcurrencies[index]
//                return
//            }
//        }
//        self.currencyIndex = 0
//        self.currency = OIMeuros
//    }

    func max(available: UInt64) -> UInt64 {
        for note in currency.bankNotes {
            if note <= available {
                return note
            }
        }
        for coin in currency.bankCoins {
            if coin <= available {
                return coin
            }
        }
        return 0
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
            if fund.shouldFly2 || fund.isFlying2      {  // flying can not go on the stack
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
                if first {
                    logger.log("  ❗️added first \(fund.id) to morph for \(morphTicker)")
                } else {
                    logger.log("  ❗️added \(fund.id) to morph for \(morphTicker)")
                }
                fund.morphTicker = first ? morphTicker : -morphTicker
                first = false
                updateFund(fund)
                toDelete.append(fund)
                counter -= 1
                amount += outValue
            }
        }
        guard counter == 0 else {
            logger.warning("  ❗️Yikes: didn't find \(nr) funds to morph, missing \(counter)")
            for var delFund in toDelete {
                logger.log("  ❗️free \(delFund.id) from morphing \(morphTicker)")
                delFund.morphTicker = nil
                updateFund(delFund)
            }
            return true
        }

        while amount >= inValue {
            amount -= inValue
            added += 1          // TODO: If we added more than 1, then we must flip more than 1
        }
        if amount > 0 {
            logger.warning("  ❗️Yikes: morph leftover:\(amount)")
        }

        guard toDelete.count > 1 else { return true }
        /// Stage 1: the fund with the highest id just got added - that is the anchor position for the morph
        var morphFund = toDelete.removeFirst()
        added -= 1
        logger.log(">>taking this anchor \(morphFund.id) \(morphFund.value) \(morphFund.state.rawValue)")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + flyDelay) {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + flyDelay) {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + flyDelay) {
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

    @discardableResult
    func addCash(value: UInt64, _ newState: FundState = .shouldFly, _ flippedVal: UInt64? = nil) -> OIMfund {
        let myTicker = ticker; ticker += 1 // TODO: atomic increment!
        let fund = OIMfund(id: myTicker,
                        value: value,
                  currencyStr: currency.currencyStr,     // currencyIndex: currencyIndex,
                        state: newState,
                   flippedVal: flippedVal)
        symLog.log(">>adding \(value) \(fund.id) \(newState)")
        funds.append(fund)
        return fund
    }

    func removeCash(id: Int, value: UInt64) {
        if let index = funds.firstIndex(where: { $0.id == id && $0.value == value }) {
            funds.remove(at: index)
        } else if let index = funds.lastIndex(where: { $0.value == value && $0.state.removing }) {
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

    @discardableResult
    func moveDown() -> Double {
        let sorted = sortByValue()

        var counter = 0.0
        var lastVal: UInt64 = 0
        for var fund in sorted {
//            withAnimation(.easeOut1.delay(counter * 0.1)) {
            withAnimation(.easeOut1) {
                fund.state = .drawer
                self.updateFund(fund)
            }
            if lastVal != fund.value {
                lastVal = fund.value
                counter += 1
            }
        }
        return counter * 0.1
    }

    func moveBack() {
        for var fund in funds {
//            if fund.state == .drawer {
                fund.state = .idle
                self.updateFund(fund)
//            }
        }
    }

    func clearFunds() {
        funds = []
    }

    func countDosh(_ dosh: OIMdenominations) -> UInt64 {
        dosh.reduce(0) {  x, y in
            x + y
        }
    }

    func flyToTarget(target: FundState, index: Int, after delay: TimeInterval) {
        let interval = fastAnimations ? 0.2 : 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            var fund = self.funds[index]
            withAnimation(.move1) {
                fund.state = target
                self.updateFund(fund)
            }
            print("flyToTarget", target, fund.id, fund.value, delay)
            if target == .curve {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    withAnimation(.move1) {
                        fund.state = .reveal
                        self.updateFund(fund)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                        withAnimation(.move1) {
                            do {
                                self.funds.remove(at: index)
                            } catch {}
                        }
                    }
                }
            } // curve
        }
    }

    func flyOneByOne(to target: FundState,
                  _ increasing: Bool = false,
                    _ duration: TimeInterval? = nil
    ) -> TimeInterval {
        var count = funds.count
        var initial: TimeInterval = 0.01
        let interval = interval(count: count,
                             duration: duration ?? (fastAnimations ? 0.6 : 1.1),
                              initial: initial)
        var index = 0
        while count > 0 {   // for each fund, small to high
            count -= 1
            flyToTarget(target: target,
                         index: increasing ? index : count,
                         after: initial)
            index += 1
            initial += interval
        }
        return initial - interval + (fastAnimations ? 0.1 : 0.2)
    }

    func setTarget(_ target: FundState,
               _ increasing: Bool = false) {
        var count = funds.count
        var index = 0
        while count > 0 {   // for each fund, small to high
            count -= 1
            var fund = self.funds[increasing ? index : count]
            fund.state = target
            self.updateFund(fund)
            index += 1
        }
    }

    func interval(count: Int,
               duration: TimeInterval,
                initial: TimeInterval = 0
    ) -> TimeInterval {
        (duration <= initial) || (count == 0) ? 0
                                              : (duration - initial) / Double(count)
    }

    func update2(_ intVal: UInt64,
                    state: FundState = .idle,
               _ duration: TimeInterval = 0,
                _ initial: TimeInterval = 0) {
        // optimize/rebuild funds
        let dosh = currency.notesCoins(intVal)
        let count = Int(countDosh(dosh.0) + countDosh(dosh.1))
        let interval = interval(count: count, duration: duration, initial: initial)
        let delay = update1(dosh.0, denominations: currency.bankNotes, state: state, interval, initial)
        update1(dosh.1, denominations: currency.bankCoins, state: state, interval, delay)
    }

    @discardableResult
    func update1(_ notesCoins: OIMdenominations,
                denominations: OIMdenominations,
                        state: FundState = .idle,
                   _ interval: TimeInterval = 0,
                    _ initial: TimeInterval = 0) -> TimeInterval {
        var array = funds
        var changed = false
        var accumulatedDelay = initial
        for (index, value) in denominations.enumerated() {
            let wanted = notesCoins[index]      // number of notes which should be shown
            var shownNotes = array.filter { $0.value == value }
            var count = shownNotes.count
            while count > wanted {
                let note = shownNotes[0]
                symLog.log("update: remove \(note.value), \(note.id)")
                if let index = array.firstIndex(of: note) {
                    array.remove(at: index)
                    changed = true
                }
                shownNotes.remove(at: 0)
                count -= 1
            }
            while count < wanted {
//                if interval == 0 {            // add all at once
                    let fund = OIMfund(id: ticker,
                                    value: value,
                              currencyStr: currency.currencyStr, // currencyIndex: currencyIndex,
                                    state: state,
                                    delay: accumulatedDelay)
                    ticker += 1
                    symLog.log("update: add \(fund.value), \(fund.id)")
                    array.append(fund)
                    changed = true
//                } else {   // add each delayed
//                    DispatchQueue.main.asyncAfter(deadline: .now() + accumulatedDelay) {
//                        withAnimation(.move1) {
//                            self.addCash(value: value, state)
//                            return
//                        }
//                    }
                    accumulatedDelay += interval
//                }
                count += 1
            }
        }
        if changed {
            funds = array
        }
        return accumulatedDelay
    }
}
