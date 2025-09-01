//  MIT License
//  by Benzy Neez
//  https://stackoverflow.com/questions/77631146/how-to-make-scrollview-shrink-to-fit-and-take-minimum-space-without-hacks
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
/**
 * @author Marc Stibane
 */
import SwiftUI

@available(iOS 16.0, *)
struct OptimalSize: Layout {
    let axes: Axis.Set

    /// Computes the optimal size for a ScrollView (which would grab all it could get otherwise)
    /// - Parameters:
    ///   - axes: Axes this content must fit in.
    init(_ axes: Axis.Set = [.horizontal, .vertical]) {
        self.axes = axes
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result: CGSize
        let horz = axes.contains(.horizontal)
        let vert = axes.contains(.vertical)

        if let firstSubview = subviews.first {
            let containerWidth = proposal.width ?? .infinity
            let containerHeight = proposal.height ?? .infinity
            let size = firstSubview.sizeThatFits(.init(width: vert ? containerWidth : nil,
                                                       height: horz ? containerHeight : nil))
            result = CGSize(width: min(size.width, containerWidth),
                            height: min(size.height, containerHeight))
        } else {
            result = .zero
        }
        return result
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        if let firstSubview = subviews.first {
            firstSubview.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                proposal: .init(width: bounds.width, height: bounds.height)
            )
        }
    }
}
