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
// MARK: -
struct SettingsToggle: View {
    var name: String
    @Binding var value: Bool
    var description: String?
    var action: () -> Void = {}

    var body: some View {
        VStack {
            Toggle(name, isOn: $value.animation())
                .font(.title2)
                .onChange(of: value) { value in
                    action()
                }

            if let desc = description {
                Text(desc)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
            }
        }.padding([.bottom], 4)
    }
}
// MARK: -
struct SettingsSpeaker: View {
    var name: String
    @Binding var value: Int
    var description: String?
    var action: (_ value: Int) -> Void = {value in }

    var body: some View {
        VStack {
            let image = (value == 0) ? "speaker.slash"
                      : (value == 1) ? "speaker.fill"
                                     : "speaker"
            HStack {
                Text(name)
                    .font(.title2)
                Text(" ")
                    .font(.largeTitle)
                Spacer()
                Image(systemName: image)
                    .font(.largeTitle)
                    .onTapGesture {
                        if value > 0 {
                            value = -1
                        } else {
                            value = value + 1
                        }
                    }
            }
//                .onChange(of: value) { value in
//                    action(value)
//                }

            if let desc = description {
                Text(desc)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
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
