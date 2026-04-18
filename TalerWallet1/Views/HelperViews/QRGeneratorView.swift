/* MIT License
 * Copyright (c) 2020 Jeeva Tamilselvan
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
import SwiftUI

struct QRGeneratorView: View {
    let text: String
    let size: CGFloat
    let logo: Image?
    let logoSize: CGFloat
    @Binding var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                if let logo {
                    logo
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSize, height: logoSize)
                }
            } else {
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("QR Code", comment: "a11y"))
        .onAppear {
//          if let uiImage = getQRCode(text: text) {
            if let data = getQRCodeData(text: text) {
                if let uiImage = UIImage(data: data)  {
                    image = uiImage
                }
            }
        }
    }

//    func getQRCode(text: String) -> UIImage? {
    func getQRCodeData(text: String) -> Data? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        let data = text.data(using: .ascii, allowLossyConversion: false)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")    // 4 levels: L M Q H 
        guard let ciimage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciimage.transformed(by: transform)
        let uiimage = UIImage(ciImage: scaledCIImage)
        return uiimage.pngData()!
    }
}

//#Preview {      // 'Previewable()' is only available in iOS 17.0 or newer
//    @Previewable @State var image: UIImage?
//    VStack {
//        QRGeneratorView(text: "Hello World!", size: 200, image: $image)
//        QRGeneratorView(text: "taler://pay-pull/exchange.demo.taler.net/7J7SNHYMCCAZ1ARY9YCB5Z9FTY0YZP8F2KDRXV94KZCQ6WAVMTX0",
//                        size: 200, image: $image)
//    }
//}
