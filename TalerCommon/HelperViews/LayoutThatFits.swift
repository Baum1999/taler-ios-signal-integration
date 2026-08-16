//  MIT License
//  Copyright © Ryan Lintott
//  https://github.com/ryanlintott/LayoutThatFits
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

@available(iOS 16.0, *)
struct LayoutThatFits: Layout {
    let axes: Axis.Set
    let layoutPreferences: [AnyLayout]
    
    /// Creates a layout using the first layout that fits in the axes provided from the array of layout preferences.
    /// - Parameters:
    ///   - axes: Axes this content must fit in.
    ///   - layoutPreferences: Layout preferences from largest to smallest.
    init(in axes: Axis.Set = [.horizontal, .vertical], _ layoutPreferences: [any Layout]) {
        self.axes = axes
        self.layoutPreferences = layoutPreferences.map { AnyLayout($0) }
    }
    
    func layoutThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> AnyLayout? {
        layoutPreferences.first(where: { layout in
            var cache = layout.makeCache(subviews: subviews)
            let size = layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
            
            let widthFits = size.width <= (proposal.width ?? .infinity)
            let heightFits = size.height <= (proposal.height ?? .infinity)
            
            return (widthFits || !axes.contains(.horizontal)) && (heightFits || !axes.contains(.vertical))
        })
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let layout = layoutThatFits(proposal: proposal, subviews: subviews, cache: &cache) ?? layoutPreferences.last else { return CGSize(width: 10, height: 10) }
        var cache = layout.makeCache(subviews: subviews)
        return layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let layout = layoutThatFits(proposal: proposal, subviews: subviews, cache: &cache) ?? layoutPreferences.last else { return }
        var cache = layout.makeCache(subviews: subviews)
        layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
    }
}
