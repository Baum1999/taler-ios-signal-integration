/* MIT License
 * Copyright (c) 2023 mevmev, Rahul Bir + Michal Šrůtek, jnpdx
 * https://stackoverflow.com/questions/74471576/make-sheet-the-exact-size-of-the-content-inside
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

fileprivate struct InnerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 10 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

fileprivate struct InnerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 10 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

fileprivate struct InnerSizeKey: PreferenceKey {
    static var defaultValue: CGSize { CGSize(width: 10, height: 10) }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    func innerHeight(_ height: Binding<CGFloat>) -> some View {
        overlay {      // background doesn't work for sheets
            GeometryReader { proxy in
                Color.clear
                    .preference(key: InnerHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(InnerHeightKey.self) { newValue in
 print("❗️InnerHeight \(newValue)❗️")
            height.wrappedValue = newValue
        }
    }

    func innerWidth(_ width: Binding<CGFloat>) -> some View {
        overlay {      // background doesn't work for sheets
            GeometryReader { proxy in
                Color.clear
                    .preference(key: InnerWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(InnerWidthKey.self) { newValue in
  print("❗️InnerWidth \(newValue)❗️")
            width.wrappedValue = newValue
        }
    }

    func innerSize(_ size: Binding<CGSize>) -> some View {
        overlay {      // background doesn't work for sheets
            GeometryReader { proxy in
                Color.clear
                    .preference(key: InnerSizeKey.self, value: proxy.size)
            }
        }
        .onPreferenceChange(InnerSizeKey.self) { newValue in
  print("❗️InnerSize \(newValue)❗️")
            size.wrappedValue = newValue
        }
    }
}
