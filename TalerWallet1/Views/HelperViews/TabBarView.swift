/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct ActionItem: View {
    private let symLog = SymLogV(0)
    let tab: TalerTab
    let onTap: () -> Void
    let onDrag: () -> Void

    @EnvironmentObject private var controller: Controller
    @AppStorage("tapped") var tapped: Int = 0
    @AppStorage("dragged") var dragged: Int = 0

    @State private var offset = CGSize.zero
    @State private var didDrag = false

    private func hopAction(_ newValue: Int) {
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

    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { gesture in
                var trans = gesture.translation
                trans.width = .zero
                if trans.height < -20 {
                    symLog.log(".onChanged: didDrag \(trans.height)")
                    withAnimation {
                        offset = .zero
                    }
                    didDrag = true
                    onDrag()    // switch to camera
                    if tapped >= TAPPED {
                        dragged += 1
                    }
                } else if trans.height < 0 {    // only drag up
                    symLog.log(".onChanged: \(trans.height)")
                    withAnimation {
                        offset = trans
                    }
                }
            }
            .onEnded { gesture in
                let trans = gesture.translation
                if didDrag {
                    symLog.log(".onEnded: didDrag \(trans.height)")
                    didDrag = false
                } else {
                    symLog.log(".onActionTab: \(trans.height)")
                    onTap()
                }
                withAnimation {
                    offset = .zero
                }
            }
    }

    var body: some View {
        let vStack = VStack(spacing: 0) {
    // show floating actions
            let withText = if #available(iOS 26.0, *) { false } else { tapped < TAPPED }
            let width = withText ? 48 : 72.0
            let height = withText ? 36 : 57.6
            let image = tab.image
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped() // Crop the image to the frame size
//                .opacity(1 - Double(abs(offset.height / 35)))
                .gesture(dragGesture())
                .onLongPressGesture(minimumDuration: 0.4) {
                    onDrag()
                }
                .onTapGesture {
                    onTap()
                    tapped += 1
                }
            if #available(iOS 26.0, *) {
                image
            } else {
                image
                    .padding(.bottom, 4)
                    .offset(offset)
            }
            if withText {
                Text(tab.title)
                    .lineLimit(1)
                    .talerFont(.body)
            }
        }   .id(tab)
//            .foregroundColor(isActive ? .accentColor : .secondary)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibility(label: Text(tab.title))
            .accessibility(addTraits: [.isButton])
            .accessibility(removeTraits: [.isImage])
            .onChange(of: controller.userAction) { newValue in
                hopAction(newValue)         // make Action button jump to indicate it can be dragged
            }

        if #available(iOS 26.0, *) {
            vStack
                .padding(.horizontal, 6)
                .glassEffect(.clear.interactive())
                .offset(offset)
        } else {
            vStack
                .frame(maxWidth: .infinity)
        }
    }
}
// MARK: -
//struct TabBarItem: View {
//    let tab: TalerTab
//
//    var body: some View {
//    }
//}
// MARK: -
struct TabBarView: View {
    private let symLog = SymLogV(0)
    @Binding var selection: TalerTab
    @Binding var hidden: Int
    let onActionTab: () -> Void
    let onActionDrag: () -> Void

    @Environment(\.keyboardShowing) var keyboardShowing
    @EnvironmentObject private var controller: Controller

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("tapped") var tapped: Int = 0

    @Namespace private var namespace

    private func tabBarItem(for tab: TalerTab) -> some View {
        
        let isActive = selection == tab
        let vStack = VStack(spacing: 0) {
            let withText = tapped < TAPPED || !minimalistic
            let size = withText ? 24.0 : 36.0
            tab.image
                .resizable()
                .renderingMode(.template)
                .tint(.black)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)

            if withText {
                if isActive {
                    Text(tab.title)
                        .bold()
                        .lineLimit(1)
                        .talerFont(.picker)
                } else {
                    Text(tab.title)
                        .lineLimit(1)
                        .talerFont(.body)
                }
            }
        }   .id(tab)
            .foregroundColor(isActive ? .accentColor : .secondary)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibility(label: Text(tab.title))
            .accessibility(addTraits: [.isButton])
            .accessibility(removeTraits: [.isImage])
        return vStack
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }

    var body: some View {
        Group {
            if keyboardShowing || hidden > 0 {
                EmptyView()
            } else {
                let actionTab = ActionItem(tab: TalerTab.actions,
                                         onTap: onActionTab,
                                        onDrag: onActionDrag)
                let balanceTab = tabBarItem(for: TalerTab.balances)
                    .onTapGesture {
                        selection = .balances
                        controller.userAction += 1
                    }
                let settingsTab = tabBarItem(for: TalerTab.settings)
                    .onTapGesture {
                        selection = .settings
                        controller.userAction += 1
                    }
                HStack(alignment: .bottom) {
                    balanceTab
                    actionTab
                    settingsTab
                }
                    .background(WalletColors().backgroundColor.ignoresSafeArea(edges: .bottom))
            }
        }
    }
}
// MARK: -
//#Preview {
//    TabBarView()
//}
