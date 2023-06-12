/* MIT License
 * Copyright (c) 2021 rob mayoff
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

fileprivate struct IconWidthKey: PreferenceKey {
    static var defaultValue: CGFloat? { nil }

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        switch (value, nextValue()) {
            case (nil, let next): value = next
            case (_, nil): break
            case (.some(let current), .some(let next)): value = max(current, next)
        }
    }
}

extension IconWidthKey: EnvironmentKey { }

extension EnvironmentValues {
    fileprivate var iconWidth: CGFloat? {
        get { self[IconWidthKey.self] }
        set { self[IconWidthKey.self] = newValue }
    }
}

fileprivate struct IconWidthModifier: ViewModifier {
    @Environment(\.iconWidth) var width

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { proxy in
                Color.clear
                    .preference(key: IconWidthKey.self, value: proxy.size.width)
            })
            .frame(width: width)
    }
}

struct EqualIconWidthLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon.modifier(IconWidthModifier())
            configuration.title //(alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
}

struct EqualIconWidthDomain<Content: View>: View {
    let content: Content
    @State var iconWidth: CGFloat? = nil

    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.iconWidth, iconWidth)
            .onPreferenceChange(IconWidthKey.self) { self.iconWidth = $0 }
            .labelStyle(EqualIconWidthLabelStyle())
    }
}
// MARK: -
#if DEBUG
struct Demo1View: View {
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Label("People", systemImage: "person.3")
                Label("Star", systemImage: "star")
                Label("This is a plane", systemImage: "airplane")
            }
            .padding()
            EqualIconWidthDomain {
                VStack(alignment: .leading) {
                    Label("People", systemImage: "person.3")
                    Label("Star", systemImage: "star")
                    Label("This is a plane", systemImage: "airplane")
                }
            }
        }
    }
}

struct Demo1_Previews: PreviewProvider {
    static var previews: some View {
        Demo1View()
    }
}


struct FancyView: View {
    var body: some View {
        EqualIconWidthDomain {
            VStack {
                Text("Le Menu")
                    .font(.caption)
                Divider()
                HStack {
                    VStack(alignment: .leading) {
                        Label(
                            title: { Text("Strawberry") },
                            icon: { Text("🍓") })
                        Label("Money", systemImage: "banknote")
                    }
                    VStack(alignment: .leading) {
                        Label("People", systemImage: "person.3")
                        Label("Star", systemImage: "star")
                    }
                }
            }
        }
    }
}

struct Demo2_Previews: PreviewProvider {
    static var previews: some View {
        FancyView()
    }
}
#endif
