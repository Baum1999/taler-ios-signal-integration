/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

enum FundState: Int {
    case idle
    case shouldFly
    case isFlying
    case flipped
}

/// data structure for a cash item on the table
public struct OIMfund: Identifiable, Equatable, Hashable {
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

    func notes() -> OIMfunds {
        let firstCoinVal = currency.bankCoins[0]
        return funds.filter { $0.value > firstCoinVal }
    }

    func coins() -> OIMfunds {
        let firstCoinVal = currency.bankCoins[0]
        return funds.filter { $0.value <= firstCoinVal }
    }

    func addCash(_ value: UInt64) {
        let fund = OIMfund(id: ticker, value: value, state: .shouldFly)
        ticker += 1
        funds.append(fund)
    }

    func removeCash(id: Int, value: UInt64) {
        if let index = funds.firstIndex(where: { $0.id == id }) {
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
