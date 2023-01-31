/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
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

struct SettingsItem<Content: View>: View {
    var name: String
    var description: String?
    var content: () -> Content
    
    init(name: String, description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.name = name
        self.description = description
        self.content = content
    }
    
    var body: some View {
        HStack {
            VStack {
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.title2)
                    .padding([.bottom], 0.01)
                if let desc = description {
                    Text(desc)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption)
                }
            }
            content()
        }.padding([.bottom], 4)
    }
}

struct SettingsToggle: View {
    var name: String
    @Binding var value: Bool
    var description: String?

    var body: some View {
        VStack {
            Toggle(name, isOn: $value.animation(.spring()))
                .font(.title2)
            if let desc = description {
                Text(desc)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
            }
        }.padding([.bottom], 4)
    }
}



struct SettingsItemPreview : View {
    @State var developerMode: Bool = false

    var body: some View {
        VStack {
            SettingsToggle(name: "Developer Mode", value: $developerMode, description: "More information intended for debugging")
        }
    }
}

struct SettingsItem_Previews: PreviewProvider {
    static var previews: some View {
        List {
            NavigationLink { } label: {
                SettingsItem (name: "Exchanges", description: "Manage list of exchanges known to this wallet") {}
            }
            SettingsItemPreview()
            SettingsItem(name: "Save Logfile", description: "Help debugging wallet-core") {
                Button("Save") {
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
        }
    }
}
