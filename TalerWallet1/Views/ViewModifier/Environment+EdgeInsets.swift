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
import SwiftUI

struct SafeAreaEdgeInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        let keyWindows = UIApplication.shared.windows.filter { $0.isKeyWindow }.first ??
                UIApplication.shared.windows[0]

        return keyWindows.safeAreaEdgeInsets
    }
}

extension EnvironmentValues {
    ///Should only be used once UIApplication is instantiated by the system
    var safeAreaEdgeInsets: EdgeInsets {
        self[SafeAreaEdgeInsetsKey.self]
    }
}

extension UIEdgeInsets {
    var insets: EdgeInsets {    // TODO: right-to-left!!!
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}

extension UIWindow {
    var safeAreaEdgeInsets: EdgeInsets {
        safeAreaInsets.insets
    }
}
