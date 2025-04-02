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

#if DEBUG
var debugAnimations = true
#endif

extension Animation {
#if DEBUG
    static var debug: Animation {
        Animation.easeInOut(duration: 2.0)
    }
#endif

    static var spring1: Animation {
        Animation.interactiveSpring(response: 0.6, dampingFraction: 0.6, blendDuration: 0.25)
    }

    static var easeIn1: Animation {
#if DEBUG
        debugAnimations ? Animation.debug : Animation.easeIn(duration: 0.25)
#else
        Animation.easeIn(duration: 0.25)
#endif
    }

    static var shake1: Animation {
#if DEBUG
        debugAnimations ? Animation.debug : Animation.spring1
#else
        Animation.spring1
#endif
    }

    static var fly1: Animation {
#if DEBUG
        debugAnimations ? Animation.debug : Animation.spring1
#else
        Animation.spring1
#endif
    }
    
    static var basic1: Animation {
#if DEBUG
        debugAnimations ? Animation.debug : Animation.default
#else
        Animation.default
#endif
    }
}
