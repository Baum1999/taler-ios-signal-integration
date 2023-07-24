/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

struct AgePicker: View {
    @Binding var ageMenuList: [Int]
    @Binding var selectedAge: Int

    func setAges(ages: [Int]?) {
        if let ages {
            var zero: [Int] = []
            if ages.count > 0 {        // need at least 1 value from exchange which is not 0
                if ages[0] != 0 {               // ensure that the first age is "0"
                    zero.insert(0, at: 0)       // if not, insert "0" at position 0
                }
                zero += ages
                if selectedAge >= zero.count {  // check for out of bounds
                    selectedAge = 0
                }
            } else {
                selectedAge = 0                 // first ensure that selected is not out of bounds
            }
            ageMenuList = zero                  // set State (will update view)
        }
    }

    var body: some View {
        if ageMenuList.count > 1 {
            VStack {
                HStack {
                    Text("If this wallet belongs to a child or teenager, the generated electronic cash should be age-restricted:")
                        .multilineTextAlignment(.leading)
                        .font(.footnote)
                    Spacer()
                }.padding(.top)
                Picker("Select age", selection: $selectedAge) {
                    ForEach($ageMenuList, id: \.self) { item in
                        let index = item.wrappedValue
                        Text((index == 0) ? "unrestricted"
                                          : "\(index) years").tag(index)
                    }
                }
            }
        }
    }
}

