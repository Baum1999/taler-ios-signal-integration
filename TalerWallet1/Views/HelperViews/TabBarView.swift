/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct TabBarView: View {
    private let symLog = SymLogV(0)
    @Binding var selection: Tab
    @Binding var userAction: Int
    @Binding var hidden: Int
    let onActionTab: () -> Void
    let onActionDrag: () -> Void

    @Environment(\.keyboardShowing) var keyboardShowing

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("tapped") var tapped: Int = 0
    @AppStorage("dragged") var dragged: Int = 0

    @State private var offset = CGSize.zero
    @State private var didDrag = false

    private func tabBarItem(for tab: Tab) -> some View {
        VStack(spacing: 0) {
            let isActions = (tab == .actions)
            let withText = isActions ? tapped < TAPPED
                                     : tapped < TAPPED || !minimalistic
            if isActions {
                let width = withText ? 48 : 72.0
                let height = withText ? 36 : 57.6
                tab.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped() // Crop the image to the frame size
                    .padding(.bottom, 4)
                    .offset(offset)
//                    .opacity(1 - Double(abs(offset.height / 35)))
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { gesture in
                                var trans = gesture.translation
                                trans.width = .zero
                                if abs(trans.height) > 30 {
                                    symLog.log(".onChanged: didDrag \(trans.height)")
                                    offset = .zero
                                    didDrag = true
                                    onActionDrag()    // switch to camera
                                    if tapped >= TAPPED {
                                        dragged += 1
                                    }
                                } else {
                                    symLog.log(".onChanged: \(trans.height)")
                                    offset = trans
                                }
                            }
                            .onEnded { gesture in
                                var trans = gesture.translation
                                if didDrag {
                                    symLog.log(".onEnded: didDrag \(trans.height)")
                                    didDrag = false
                                } else {
                                    symLog.log(".onActionTab: \(trans.height)")
                                    onActionTab()
                                }
                                offset = .zero
                            }
                    )
            } else {
                let size = withText ? 24.0 : 36.0
                tab.image
                    .resizable()
                    .renderingMode(.template)
                    .tint(.black)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            }
            if withText {
                Text(tab.title)
                    .lineLimit(1)
                    .talerFont(.body)
            }
        }.id(tab)
        .foregroundColor(selection == tab ? .accentColor : .secondary)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibility(label: Text(tab.title))
        .accessibility(addTraits: [.isButton])
        .accessibility(removeTraits: [.isImage])
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func userAction(_ newValue: Int) {
        if tapped >= TAPPED && dragged < DRAGGED {
            withAnimation(Animation.easeOut(duration: DRAGDURATION).delay(DRAGDELAY)) {
                offset.height = -50
            }
            withAnimation(Animation.easeOut(duration: DRAGSPEED).delay(DRAGDELAY + DRAGDURATION + DRAGSPEED)) {
                offset.height = 10
            }
            withAnimation(Animation.easeOut(duration: DRAGSPEED/2).delay(DRAGDELAY + DRAGDURATION + 2.5*DRAGSPEED)) {
                offset.height = 0
            }
        }
    }
    var body: some View {
        Group {
            if keyboardShowing || hidden > 0 {
                EmptyView()
            } else {
                let actionTab = tabBarItem(for: Tab.actions)
                let balanceTab = tabBarItem(for: Tab.balances)
                let settingsTab = tabBarItem(for: Tab.settings)
                HStack(alignment: .bottom) {
                    balanceTab.onTapGesture { selection = .balances; userAction += 1 }
                    actionTab.onTapGesture {
                        onActionTab()
                        tapped += 1
//                        dragged = 0
                    }
                    settingsTab.onTapGesture { selection = .settings; userAction += 1 }
                }
                .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.bottom))
                .onChange(of: userAction) { newValue in
                    userAction(newValue)
                }
            }
        }
    }
}
// MARK: -
//#Preview {
//    TabBarView()
//}
