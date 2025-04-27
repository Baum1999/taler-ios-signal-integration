//  MIT License
//  Copyright © SwiftUI-Lab
//  https://swiftui-lab.com/matchedGeometryEffect-part2
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

var fastAnimations = true
#if DEBUG
var debugAnimations = true
#endif

extension Animation {
#if DEBUG
    static var debug: Animation { .easeInOut(duration: 2.0) }
#endif

    static var springFast: Animation {
        .interactiveSpring(response: 0.6, dampingFraction: 0.6, blendDuration: 0.25)
    }
    static var springSlow: Animation {
        .interactiveSpring(response: 0.9, dampingFraction: 0.75, blendDuration: 0.5)
    }

    static var easeIn1: Animation {
#if DEBUG
        if debugAnimations { return .debug }
#endif
        return .easeIn(duration: (fastAnimations ? 0.25 : 0.5))
    }

    static var fly1: Animation {
#if DEBUG
        if debugAnimations { return .debug }
#endif
        return fastAnimations ? .springFast
                              : .springSlow
    }

    static var remove1: Animation {
#if DEBUG
        if debugAnimations { return .debug }
#endif
        return fastAnimations ? .springFast.delay(0.2)
                              : .springSlow.delay(0.5)
    }

    static var basic1: Animation {
#if DEBUG
        if debugAnimations { return .debug }
#endif
        /// The `default` animation is ``spring(response:dampingFraction:blendDuration:)``
        /// with:
        /// - `response` equal to `0.55`
        /// - `dampingFraction` equal to `1.0`
        /// - `blendDuration` equal to `0.0`
        ///
        /// Prior to iOS 17, macOS 14, tvOS 17, and watchOS 10, the `default` animation is ``easeInOut``.
        return fastAnimations ? .default
                              : .springSlow
    }
}
