/* MIT License
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
 *
 */
import SwiftUI

extension Image {
    init(_ name: String, _ sysName: String, fallback: String = SYSTEM_DUMMY1) {
        if let uiImage = UIImage(named: name) {
            self.init(uiImage: uiImage)
        } else if let sysImage = UIImage(systemName: sysName) {
            self.init(uiImage: sysImage)
        } else {
            self.init(systemName: fallback)
        }
    }

    /// Decode an `ImageDataUrl` as the protocol defines it: a data URL with an explicit
    /// mediatype (`image/png` or `image/jpeg`) and the `base64` parameter.
    /// Anything else must be rejected without ever being resolved: the string comes from
    /// the merchant, and `NSData(contentsOf:)` would *fetch* an `http(s):` URL - blocking
    /// the main thread and telling the merchant when (and how often) the user looks at
    /// the transaction - or read a local file for a `file:` URL.
    init?(imageBase64: String) {
        let anchored: String.CompareOptions = [.caseInsensitive, .anchored]
        guard let dataUrlPrefix = imageBase64.range(of: "data:image/png;base64,", options: anchored)
                               ?? imageBase64.range(of: "data:image/jpeg;base64,", options: anchored),
              let data = Data(base64Encoded: String(imageBase64[dataUrlPrefix.upperBound...])),
              let uiImage = UIImage(data: data)
        else { return nil }

        self.init(uiImage: uiImage)
    }
}
