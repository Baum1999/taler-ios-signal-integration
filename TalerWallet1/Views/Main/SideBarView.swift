/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

fileprivate let sidebarWidth = 200.0

struct SidebarItem {
    var name: String
    var sysImage: String?
    var view: AnyView
}

struct SideBarView: View {
    private let symLog = SymLogV(0)
    let views: [SidebarItem]
    @Binding var currentView: Int
    @Binding var sidebarVisible: Bool
    @State private var rotationEnabled = false

    var body: some View {
        HStack {    // sideView left, clear dismiss target right
            EqualIconWidthDomain {
                VStack(spacing: 10) {
                    let gnuTaler = String("GNU Taler")  // this should NOT be translated
                    Link(gnuTaler, destination: URL(string:"https://taler.net")!)
                        .font(.talerLargeTitle)  //.bold()     iOS 16
                        .padding(.top, 30)
                    RotatingTaler(size: 100, rotationEnabled: $rotationEnabled)
                        .onTapGesture {
                            rotationEnabled.toggle()
                        }
                    ForEach(0..<views.count, id: \.self) { i in
                        Button {
                            symLog.log("sidebar item \"\(views[i].name)\" selected")
                            sidebarVisible = false      // slide sidebar to the left
                            withAnimation(.easeInOut) {currentView = i}                     // switch to the view the user selected
                        } label: {
                            if let sysImage = views[i].sysImage {
                                Label(views[i].name, systemImage: sysImage)
                                    .frame(maxWidth: sidebarWidth, alignment: .leading)
                            } else {
                                Text(views[i].name)
                                    .frame(maxWidth: sidebarWidth)
                            }
                        }
                        .padding()
                        .buttonStyle(.borderless)
                        .font(.talerTitle2)
                        .disabled(i == currentView)
                        .accessibilityHidden(i == currentView)      // don't suggest the current item
                    }
                    Spacer()
                }
                .background(WalletColors().sideBackground)
                .frame(width: sidebarWidth, alignment: .center)
                // TODO: use leading instead of sidebarWidth for right-to-left
                .offset(x: sidebarVisible ? 0 : -sidebarWidth)
                //  .onAppear can NOT be used here, because we don't show or dismiss this view,
                //   but only slide it left or right - so it is always there.
            }
            // this is just a target for a tap gesture outside the sidebar to dismiss it
            Color.clear
                .frame(maxWidth: sidebarVisible ? .infinity : 0, maxHeight: .infinity, alignment: .leading)
                // TODO: right-to-left ?
                .offset(x: sidebarVisible ? sidebarWidth : 0)
                .contentShape(Rectangle())
                .onTapGesture {
                    sidebarVisible = false
                }
        }
        .animation(.linear  //(duration: SLIDEDURATION)
                   , value: sidebarVisible)
    }
}
// MARK: -
#if DEBUG
fileprivate struct BindingViewContainer : View {
    @State var currentView: Int = 0
    @State var sidebarVisible: Bool = true
    var views: [SidebarItem]

    var body: some View {
        ZStack(alignment: .leading) {
            views[currentView].view
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            SideBarView(views: views, currentView: $currentView, sidebarVisible: $sidebarVisible)
        }
    }
}

struct SideBarView_Previews: PreviewProvider {
    static var views: [SidebarItem] {[
        SidebarItem(name: "Balances",
                sysImage: "creditcard.fill",        // TODO: Wallet Icon
                    view: AnyView(WalletEmptyView())),
        SidebarItem(name: "Settings",
                sysImage: "gearshape.fill",
                    view: AnyView(WalletEmptyView()))
    ]}
    static var previews: some View {
        BindingViewContainer(views: views)
    }
}
#endif
