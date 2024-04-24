/* MIT License
 * Copyright (c) 2022 young rtSwift
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import SwiftUI

public extension View {
    var anyView: AnyView {
        AnyView(self)
    }
}
// MARK: -
// Our ListStyle each case corresponds to a SwiftUI.ListStyle
// Here we make it CaseIterable for SwiftUI.ForEach
// and the UI Display name
public enum MyListStyle: String, CaseIterable, Hashable {
    case automatic
    case grouped
    case inset
    case insetGrouped
    case plain
    case sidebar

    // map to SwiftUI ListStyle
    var style: any SwiftUI.ListStyle {
        switch self {
            case .automatic:    return .automatic
            case .grouped:      return .grouped
            case .inset:        return .inset
            case .insetGrouped: return .insetGrouped
            case .plain:        return .plain
            case .sidebar:      return .sidebar
        }
    }

    var displayName: String {
        String(self.rawValue)
    }
}
// MARK: -
#if DEBUG
struct AnyViewDemo: View {
    @State private var selectedStyle = MyListStyle.automatic

    let sections  = ["Breakfast" : ["pancakes", "bacon", "orange juice"],
                                    "Lunch"     : ["sandwich", "chips", "lemonade"],
                                    "Dinner"    : ["spaghetti", "bread", "water"]]


    var body: some View {
        VStack {
            Picker("List Style:", selection: $selectedStyle) {
                ForEach(MyListStyle.allCases, id: \.self) {
                    Text($0.displayName.capitalized).tag($0)
                }
            }

            let keys = Array(sections.keys)
            List(keys.indices, id: \.self) { index in
                let key = keys[index]
                if let section = sections[key] {
                    Section(key) {
                        ForEach(section, id: \.self) { item in
                            Text(item)
                        }
                    }
                }
            }
            .listStyle(selectedStyle.style)
            .anyView
        }
    }
}

struct AnyViewDemo_Previews: PreviewProvider {
    static var previews: some View {
        AnyViewDemo()
    }
}
#endif
