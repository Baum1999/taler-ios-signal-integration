/* MIT License
 * Copyright (c) 2024 Sucodee
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

// Use radius: 0 for rect instead of rounded rect
struct GradientBorder<Content: View>: View {
    let size: CGFloat
    let radius: CGFloat
    let lineWidth: CGFloat
    let color: Color
    let background: Color
    var content: () -> Content

    @State var rotation: CGFloat = 0

    var body: some View {
        HStack {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .frame(width: size, height: size).foregroundStyle(background)
                    .shadow(color: background.opacity(0.5), radius: 10, x: 0, y: 10)
                let gradient = Gradient(colors: [
                    color.opacity(0.01),
                    color,
                    color,
                    color.opacity(0.01)]
                )
                let linearGradient = LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom)
                let rotatingRect = Rectangle()
                    .frame(width: size*2, height: size/2)
                    .foregroundStyle(linearGradient)
                    .rotationEffect(.degrees(rotation))
                let border = lineWidth - 0.5
                rotatingRect
                    .mask {
                        RoundedRectangle(cornerRadius: radius - lineWidth/2, style: .continuous)
                            .stroke(lineWidth: lineWidth)
                            .frame(width: size - border, height: size - border)
                    }
                content()
            }
            .frame(width: size, height: size)
            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
extension GradientBorder {
    init(size: CGFloat, radius: CGFloat = 20.0, lineWidth: CGFloat = 4.0, color: Color, background: Color, content: @escaping () -> Content) {
        self.size = size
        self.radius = radius
        self.lineWidth = lineWidth
        self.color = color
        self.background = background
        self.content = content
    }
}
// MARK: -
struct GradientBorder_Previews: PreviewProvider {
    static var previews: some View {

        GradientBorder(size: 260,
//                     radius: 1,
//                  lineWidth: 2,
                      color: .blue,
                 background: .yellow) {
            Text(verbatim: "Preview")
        }
    }
}
