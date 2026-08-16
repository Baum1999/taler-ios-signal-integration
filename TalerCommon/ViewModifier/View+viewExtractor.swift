/* MIT License
 * Copyright (c)
 * https://stackoverflow.com/questions/57132417/swiftui-scrollview-is-not-able-to-disable-vertical-bounce
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

extension View {
    @ViewBuilder
    func viewExtractor(result: @escaping (UIView) -> ()) -> some View {
        self
            .background(ViewExtractorHelper(result: result))
            .compositingGroup()
    }
}

fileprivate struct ViewExtractorHelper: UIViewRepresentable {
    var result: (UIView) -> ()

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let superView = view.superview?.superview?.subviews.last?.subviews.first {
                result(superView)
            }
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {

    }
}
