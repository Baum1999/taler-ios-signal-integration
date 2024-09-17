/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct TabBarView: View {
    @Binding var selection: Tab
    let onActionTab: () -> Void

    @Environment(\.keyboardShowing) var keyboardShowing

    @AppStorage("minimalistic") var minimalistic: Bool = false

    private func tabBarItem(for tab: Tab) -> some View {
        VStack(spacing: 0) {
            if tab == .actions {
                let width = 72.0
                let height = 57.6
                tab.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped() // Crop the image to the frame size
                    .padding(.bottom, 4)
            } else {
                let size = minimalistic ? 36.0 : 24.0
                tab.image
                    .resizable()
                    .renderingMode(.template)
                    .tint(.black)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                if !minimalistic {
                    Text(tab.title)
                        .lineLimit(1)
                        .talerFont(.body)
                    //                        .padding(.top, 2)
                }
            }
        }
        .foregroundColor(selection == tab ? .accentColor : .secondary)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibility(label: Text(tab.title))
        .accessibility(addTraits: [.isButton])
    }

    var body: some View {
        Group {
            if keyboardShowing {
                EmptyView()
            } else {
                HStack(alignment: .bottom) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        tabBarItem(for: tab)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if tab == .actions {
                                    onActionTab()
                                } else {
                                    selection = tab
                                }
                            }
                    }
                }
                .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.bottom))
            }
        }
    }
}
// MARK: -
//#Preview {
//    TabBarView()
//}
