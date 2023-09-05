/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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
                    .font(.talerTitle2)
                    .padding([.bottom], 0.01)
                if let desc = description {
                    Text(desc)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.talerCaption)
                }
            }
            content()
                .font(.talerBody)
        }.padding([.bottom], 4)
    }
}
// MARK: -
struct SettingsToggle: View {
    var name: String
    @Binding var value: Bool
    var description: String?
    var action: () -> Void = {}

    var body: some View {
        VStack {
            Toggle(name, isOn: $value.animation())
                .font(.talerTitle2)
                .onChange(of: value) { value in
                    action()
                }

            if let desc = description {
                Text(desc)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.talerCaption)
            }
        }.padding([.bottom], 4)
    }
}
// MARK: -
struct SettingsFont: View {
    let title: String
    let value: Int
    let action: (Int) -> Void

    @State private var selected = 0
    let fonts = [String(localized: "Standard iOS Font"), "Atkinson-Hyperlegible", "Nunito"]

    var body: some View {
        Picker(title, selection: $selected, content: {
            ForEach(0..<fonts.count, id: \.self, content: { index in
                Text(fonts[index]).tag(index)
            })
        })
            .font(.talerTitle2)
            .pickerStyle(.menu)
            .onAppear() {
                withAnimation { selected = value }
            }
            .onChange(of: selected) { selected in
                action(selected)
            }
    }
}
// MARK: -
struct SettingsStyle: View {
    let title: String
    @Binding var myListStyle: MyListStyle

    var body: some View {
        HStack {
            Text(title)
                .font(.talerTitle2)
            Spacer()
            Picker(selection: $myListStyle) {
                ForEach(MyListStyle.allCases, id: \.self) {
                    Text($0.displayName.capitalized).tag($0)
                        .font(.talerTitle2)
                }
            } label: {}
                .pickerStyle(.menu)
//                .frame(alignment: .trailing)
//                .background(WalletColors().buttonBackColor(pressed: false, disabled: false))  TODO: RoundRect
        }
    }
}
// MARK: -
struct SettingsSpeaker: View {
    var name: String
    @Binding var value: Int
    var description: String?
    var action: (_ value: Int) -> Void = {value in }

    func imageName(_ value: Int) -> (String, String) {
        return (value == 0) ? ("speaker.slash", String(localized:"off", comment: "Accessibility String for Payment Sounds Off"))
             : (value == 1) ? ("speaker.fill", String(localized:"Taler Sounds", comment: "Accessibility String for Payment Sounds"))
                            : ("speaker", String(localized:"Apple Sounds", comment: "Accessibility String for Payment Sounds"))
    }
    var body: some View {
        VStack {
            let image = imageName(value)
            HStack {
                Text(name)
                    .font(.talerTitle2)
                Text(" ")
                    .font(.talerLargeTitle)
                Spacer()
                Image(systemName: image.0)
                    .font(.talerLargeTitle)
                    .accessibilityLabel(image.1)
                    .onTapGesture {
                        if value > 0 {
                            value = -1
                            Controller.shared.playSound(1)
                        } else {
                            value = value + 1
                            Controller.shared.playSound(value)
                        }
                    }
            }
//                .onChange(of: value) { value in
//                    action(value)
//                }

            if let desc = description {
                Text(desc)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.talerCaption)
            }
        }.padding([.bottom], 4)
    }
}
// MARK: -
#if DEBUG
struct SettingsItemPreview : View {
    @State var developerMode: Bool = false
    @State var playSounds: Int = 0

    var body: some View {
        VStack {
            SettingsToggle(name: "Developer Mode", value: $developerMode,
                    description: "More information intended for debugging")
            SettingsSpeaker(name: String(localized: "Play Payment Sounds"), value: $playSounds,
                     description: String(localized: "After a transaction finished"))

        }
    }
}

struct SettingsItem_Previews: PreviewProvider {
    static var previews: some View {
        List {
            SettingsItem (name: "Exchanges", description: "Manage list of exchanges known to this wallet") {}
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
#endif
