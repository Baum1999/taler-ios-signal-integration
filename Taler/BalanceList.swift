/*
 * This file is part of GNU Taler
 * (C) 2021 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */

import SwiftUI

/*struct IdentifiedArray<T>: RandomAccessCollection {
    struct Item {
        var id: Int
        var item: T
    }
    
    typealias Element = Item
    typealias ItemArray = [Item]
    typealias Index = ItemArray.Index
    typealias SubSequence = IdentifiedArray<T>
    typealias Indices = ItemArray.Indices
    
    var items: ItemArray
    var startIndex: ItemArray.Index {
        get {
            return items.startIndex
        }
    }
    var endIndex: ItemArray.Index {
        get {
            return items.endIndex
        }
    }
    
    subscript(position: ItemArray.Index) -> Element {
        get {
            return items[position]
        }
        set(value) {
            items[position] = value
        }
    }
    
    init(_ array: [T]) {
        self.items = array.enumerated().map({ (index, element) in
            return Item(id: index, item: element)
        })
    }
}

struct BalanceList: View {
    var balances: IdentifiedArray<Balance>
    
    var body: some View {
        List(balances, id: \.id) { balance in
            BalanceRow(balance: balance.item)
        }
    }
}

struct BalanceList_Previews: PreviewProvider {
    static var previews: some View {
        try! BalanceList(balances: IdentifiedArray<Balance>([
            Balance(available: Amount(fromString: "USD:0.01"), pendingIncoming: Amount(fromString: "USD:0.02"), pendingOutgoing: Amount(fromString: "USD:0.03"), requiresUserInput: true),
            Balance(available: Amount(fromString: "EUR:0.02"), pendingIncoming: Amount(fromString: "EUR:0.01"), pendingOutgoing: Amount(fromString: "EUR:0.03"), requiresUserInput: false)
        ]))
    }
}*/
