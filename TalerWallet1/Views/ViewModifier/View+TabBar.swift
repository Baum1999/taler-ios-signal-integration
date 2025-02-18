//  MIT License
//  Copyright 2021 alexis https://github.com/alexis-ag/swiftui_classic-tabview_show-hide
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
//  and associated documentation files (the "Software"), to deal in the Software without restriction,
//  including without limitation the rights to use, copy, modify, merge, publish, distribute,
//  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

/*
    SwiftUI has quite poor TabView, it doesn't allow you to
        set any icon size
        set default colors for system icons and labels
        place more complicated views than simple image
        resize image for icon just in time
        hide the tab bar when you don't need it
    Idea:
        place Swiftui TabView
        hide it's tab bar forever, but use for storing content
        show our own custom tab bar
*/
import Foundation
import SwiftUI

extension EnvironmentValues {
    ///TabView raw height; does not include bottom safe area.
    var tabBarHeight: CGFloat {
        get { self[TabBarHeightEnvironmentKey.self] }
        set { self[TabBarHeightEnvironmentKey.self] = newValue }
    }
}

struct TabBarHeightEnvironmentKey: EnvironmentKey {
    static var defaultValue: CGFloat = 0
}



extension View {
    /// Read TabView height from underlying  UITabBarController  and keep it in property passed by binding.
    ///
    /// # Usage
    /// ```
    /// @State private var tabViewHeight: CGFloat = 0
    /// TabItem().keepTabViewHeight(in: $tabViewHeight)
    /// ```
    func keepTabViewHeight(
            in storage: Binding<CGFloat>,
            includingSeparator tabViewHeightShouldIncludeSeparator: Bool = true
    ) -> some View {
        background(TabBarAccessor { tabBar in
            let onePixel: CGFloat = 1/3
            let separatorHeight: CGFloat = tabViewHeightShouldIncludeSeparator ? onePixel : 0
            DispatchQueue.main.async {
                // -4 still hides the "visible" SwiftUI tabBar, but leaves it available for A11Y voiceOver
                // no longer necessary if we only hide the SwiftUI tabBar when our custom tabBar is hidden
                storage.wrappedValue = tabBar.bounds.height + separatorHeight // - 4
            }
        })
    }
}

// Helper bridge to UIViewController to access enclosing UITabBarController
// and thus its UITabBar
struct TabBarAccessor: UIViewControllerRepresentable {
    var callback: (UITabBar) -> Void
    private let proxyController = ViewController()

    func makeUIViewController(context: UIViewControllerRepresentableContext<TabBarAccessor>) ->
            UIViewController {
        proxyController.callback = callback
        return proxyController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<TabBarAccessor>) {
    }

    typealias UIViewControllerType = UIViewController

    private class ViewController: UIViewController {
        var callback: (UITabBar) -> Void = { _ in }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if let tabBar = self.tabBarController {
                self.callback(tabBar.tabBar)
            }
        }
    }
}

// MARK: - Content
extension View {
    func hideTabBar(_ hidden: Binding<Int>) -> some View {
        modifier(HideTabBarModifier(tabBarHidden: hidden))
    }
}

struct HideTabBarModifier: ViewModifier {
    @Binding var tabBarHidden: Int
    @Environment(\.safeAreaEdgeInsets) private var safeAreaEdgeInsets
    @Environment(\.tabBarHeight) private var tabBarHeight

    func body(content: Content) -> some View {
        let padding = tabBarHidden == 0 ? 0
                                        : tabBarHeight
        content
            .padding(.bottom, -safeAreaEdgeInsets.bottom - padding)
    }
}
