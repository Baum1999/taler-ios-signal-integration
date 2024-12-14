/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */

import SwiftUI

/// invisible NavigationLink triggered by a Bool or Int?
/// call either like this
///     .background( NavLink($buttonSelected) { destination } )
/// or
///     let actions = Group {
///         NavLink(1, $actionSelected) { dest1 }
///         NavLink(2, $actionSelected) { dest2 }
///     }
/// and then
///    .background(actions)


struct NavLink <Content : View> : View {
    let tag: Int
    @Binding var selection: Int?
    @Binding var isActive: Bool
    let content: Content

    init(_ tag: Int,
         _ selection: Binding<Int?>,
         _ isActive: Binding<Bool> = .constant(false),
         @ViewBuilder contentBuilder: () -> Content
    ) {
        self.tag = tag
        self._selection = selection
        self.content = contentBuilder()
        self._isActive = isActive
    }

    init(_ isActive: Binding<Bool>,
         _ selection: Binding<Int?> = .constant(nil),
         @ViewBuilder contentBuilder: () -> Content
    ) {
        self.tag = 0
        self._selection = selection
        self.content = contentBuilder()
        self._isActive = isActive
    }

    var body: some View {
        if tag != 0 {       // actions: $navModel.actionSelected will hide the tabBar
            NavigationLink(destination: content, tag: tag, selection: $selection)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()
        } else {            // shortcuts, AddButton
            NavigationLink(destination: content, isActive: $isActive)
            { EmptyView() }.frame(width: 0).opacity(0).hidden()
        }
    }
}
