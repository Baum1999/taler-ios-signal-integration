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
    case shaking
    case flying
    case flipped
}

/// data structure for a cash item on the table
public struct OIMfund: Identifiable, Equatable, Hashable {
    let value: UInt64
    var fundState: FundState
    public let id: UUID                // support multiple funds with the same value

    var match: String {
        if fundState == .flying {
            return String(value)
        }
        return String("\(id)")
//        return String("-\(value)")
    }
}
public typealias OIMfunds = [OIMfund]

//public struct OIMfunds: Identifiable, Hashable {
//    var funds: [OIMfund]
//    public let id: UUID                // support multiple funds with the same value
//}
// MARK: -
class OIMcash: ObservableObject {
    var currency: OIMcurrency
    @Published var shake: UInt64 = 0
    @Published var funds: OIMfunds = []
//    @Published var funds = OIMfunds(funds: [], id: UUID())

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

    func insertFund(_ item: OIMfund) {
        var didInsert = false
//        for (index, fund) in funds.funds.enumerated() {
        for (index, fund) in funds.enumerated() {
            if !didInsert {
                if fund.value < item.value {
                    funds.insert(item, at: index)
//                    funds.funds.insert(item, at: index)
                    didInsert = true
                    break
                }
            }
        }
        if !didInsert {
            funds.append(item)
//            funds.funds.append(item)
        }
    }

    func addCash(_ value: UInt64) {
        let fund = OIMfund(value: value, fundState: .flying, id: UUID())
        insertFund(fund)
    }

    func removeCash(value: UInt64) {
        if let index = funds.lastIndex(where: { $0.value == value && $0.fundState == .flipped }) {
//        if let index = funds.funds.lastIndex(where: { $0.value == value && $0.fundState == .idle }) {
            funds.remove(at: index)
//            funds.funds.remove(at: index)
        } else if let index = funds.firstIndex(where: { $0.value == value }) {
//        } else if let index = funds.funds.firstIndex(where: { $0.value == value }) {
            funds.remove(at: index)
//            funds.funds.remove(at: index)
        }
    }

    func updateFund(_ item: OIMfund) {
        let itemID = item.id
        funds = funds.map {
//        funds.funds = funds.funds.map {
            $0.id == itemID ? item : $0
        }
    }

//    func sortedFunds() -> OIMfunds {
//        Self.sorted(funds)
//    }
//
//    static func sorted(_ array: OIMfunds) -> OIMfunds {
//        array.sorted {
//            $0.value > $1.value
//            && $0.fundState.rawValue < $1.fundState.rawValue
//        }
//    }

    func update(_ notesCoins: OIMnotesCoins, currency: OIMcurrency) {
        let chng1 = update(notesCoins.0, currencyNotesCoins: currency.bankNotes)
        let chng2 = update(notesCoins.1, currencyNotesCoins: currency.bankCoins)
    }

    func update(_ notesCoins: OIMdenominations, currencyNotesCoins: OIMdenominations) -> Bool {
        var array = funds
//        var array = funds.funds
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
//                let note = OIMcashItem(value: value, pos: -1, isFlying: false, shake: false, id: UUID())
                let note = OIMfund(value: value, fundState: .idle, id: UUID())
                print("update: add \(note.value)")
                array.append(note)
                changed = true
                count += 1
            }
        }
        if changed {
            funds = array
//            funds.funds = array
        }
        return changed
    }
}
