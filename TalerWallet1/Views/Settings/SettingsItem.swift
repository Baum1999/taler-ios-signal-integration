/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct SettingsImage: View {
    let imageName: String?

    var hasImage: Bool {
        if let imageName {
            return UIImage(named: imageName) != nil
        }
        return false
    }

    var hasSysImage: Bool {
        if let imageName {
            return UIImage(systemName: imageName) != nil
        }
        return false
    }

    var body: some View {
        if hasImage {
            Image(imageName!)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
        } else if hasSysImage {
            Image(systemName: imageName!)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .padding(.horizontal, 2)
        } else {
            EmptyView()
        }
    }
}

struct SettingsDescription: View {
    let id1: String?
    let description: String?

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        if !minimalistic {
            if let desc = description {
                Text(desc)
                    .id(id1 == nil ? nil : id1! + "_T")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .talerFont(.caption)
            }
        }
    }
}
// MARK: -
struct SettingsBase<Content: View>: View {
    let id1: String?
    let description: String?
    let content: () -> Content

    init(id1: String?, description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.id1 = id1
        self.description = description
        self.content = content
    }

    var body: some View {
        let isWeb = id1?.hasPrefix("web") ?? false
        let foreColor = isWeb ? Color.accentColor
                              : .primary
        VStack {
            content()
                .id(id1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(foreColor)
                .talerFont(.title2)
                .padding([.bottom], 0.01)
            SettingsDescription(id1: id1, description: description)
        }.id(id1 == nil ? nil : id1! + "_V")
    }
}
// MARK: -
struct SettingsItem<Content: View>: View {
    let name: String
    let id1: String?
    let imageName: String?
    let description: String?
    let content: () -> Content

    init(name: String, id1: String, imageName: String? = nil, description: String? = nil,
         @ViewBuilder content: @escaping () -> Content
    ) {
        self.name = name
        self.id1 = id1
        self.imageName = imageName
        self.description = description
        self.content = content
    }
    
    var body: some View {
        HStack {
            SettingsImage(imageName: imageName)

            SettingsBase(id1: id1, description: description) {
                Text(name)
            }
            content()
                .talerFont(.body)
        }.id(id1 == nil ? nil : id1! + "_H")
            .accessibilityElement(children: .combine)
            .padding([.bottom], 4)
    }
}
// MARK: -
struct SettingsToggle: View {
    let name: String
    @Binding var value: Bool
    let id1: String?
    let imageName: String?
    let description: String?
    let action: (_ newValue: Bool) -> Void

    init(name: String, value: Binding<Bool>, id1: String? = nil,
         imageName: String? = nil,
         description: String? = nil,
         action: @escaping (_ newValue: Bool) -> Void = {_ in}
    ) {
        self.name = name
        self._value = value
        self.id1 = id1
        self.imageName = imageName
        self.description = description
        self.action = action
    }

    var body: some View {
        let accLabel: String = if let description {
            name + ", " + description
        } else {
            name
        }
        HStack {
            SettingsImage(imageName: imageName)

            SettingsBase(id1: id1, description: description) {
                Toggle(name, isOn: $value.animation())
                    .accessibility(sortPriority: 1)
                    .onChange(of: value) { value in
                        action(value)
                    }
            }
        }.id(id1 == nil ? nil : id1! + "_H")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accLabel)
        .padding([.bottom], 4)
    }
}
// MARK: -
struct SettingsFont: View {
    let title: String
    let value: Int
    let action: (Int) -> Void

    @State private var selectedFont = 0
    let fonts = [String(localized: "Standard iOS Font"), "Atkinson-Hyperlegible", "Nunito"]

    var body: some View {
        Picker(title, selection: $selectedFont, content: {
            ForEach(0..<fonts.count, id: \.self, content: { index in
                Text(fonts[index]).tag(index)
            })
        })
            .talerFont(.title2)
            .pickerStyle(.menu)
            .onAppear() {
                withAnimation { selectedFont = value }
            }
            .onChange(of: selectedFont) { selectedF in
                action(selectedF)
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
                .talerFont(.title2)
            Spacer()
            Picker(selection: $myListStyle) {
                ForEach(MyListStyle.allCases, id: \.self) {
                    Text($0.displayName.capitalized).tag($0)
                        .talerFont(.title2)
                }
            } label: {}
                .pickerStyle(.menu)
//                .frame(alignment: .trailing)
//                .background(WalletColors().buttonBackColor(pressed: false, disabled: false))  TODO: RoundRect
        }
        .accessibilityElement(children: .combine)
    }
}
// MARK: -
struct SettingsTriState: View {
    var name: String
    @Binding var value: Int
    let id1: String?
    var description: String?
    var action: (_ value: Int) -> Void = {value in }

    func imageName(_ value: Int) -> (String, String) {
        return (value == 0) ? ("eye.slash", "Off")
             : (value == 1) ? ("eye",       "Type only")
                            : ("eye.fill",  "Type and JSON")
    }
    var body: some View {
        let image = imageName(value)

        VStack {
            HStack {
                Text(name)
                    .talerFont(.title2)
                Spacer()
                Text(verbatim: " ")
                    .talerFont(.largeTitle)
                Button {
                    if value > 0 {
                        value = -1
                        action(value)
                        Controller.shared.playSound(1)
                    } else {
                        value = value + 1
                        action(value)
                        Controller.shared.playSound(value)
                    }
                } label: {
                    Image(systemName: image.0)
                        .talerFont(.largeTitle)
                }
            }

            SettingsDescription(id1: id1, description: description)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibility(value: Text(image.1))
        .accessibilityHint(description ?? EMPTYSTRING)
        .padding([.bottom], 4)
    }
}
// MARK: -
#if DEBUG
struct SettingsItemPreview : View {
    @State var developerMode: Bool = false
    @State var observe: Int = 0

    var body: some View {
        VStack {
            SettingsToggle(name: "Developer Preview", value: $developerMode, id1: "dev1",
                    description: "More information intended for debugging")
            SettingsTriState(name: "Observe walletCore", value: $observe,
                              id1: "observe",
                      description: "on LocalConsole")
        }
    }
}

struct SettingsItem_Previews: PreviewProvider {
    static var previews: some View {
        List {
            SettingsItem(name: "Exchanges", id1: "list",
                  description: "Manage list of exchanges known to this wallet") {}
            SettingsItemPreview()
            SettingsItem(name: "Save Logfile", id1: "save",
                  description: "Help debugging wallet-core") {
                Button("Save") { }
                    .buttonStyle(.bordered)
                    .disabled(true)
            }
        }
    }
}
#endif
