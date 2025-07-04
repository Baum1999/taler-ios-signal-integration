/* MIT License
 * Copyright (c) 2025 by Fatbobman(东坡肘子)
 *  X: @fatbobman
 *  Mastodon: @fatbobman@mastodon.social
 *  GitHub: @fatbobman
 *  Blog: https://fatbobman.com
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
 *    added strikethrough,
 *    simplified LayoutMode to Int,
 *    multiple TruncationStatus PreferenceKey
 */
import SwiftUI

//@available(iOS 16.0, *)
struct TruncationDetectingText: View {
    // MARK: - Properties

    private let content: String
    private let maxLines: Int?
    private let layout: Int
    private let index: Int
    private let strikeColor: Color?

    @State private var actualSize: CGSize = .zero
    @State private var naturalHeightSize: CGSize = .zero
    @State private var naturalWidthSize: CGSize = .zero

    /// Indicates whether the text content is truncated under current constraints
    private var isContentTruncated: Bool? {
        guard actualSize != .zero,
              naturalWidthSize != .zero,
              naturalHeightSize != .zero
        else {
            return nil
        }

        switch maxLines {
            case .none:
                return false
            case 1:
                // For single line: check if natural width exceeds actual width
                return naturalWidthSize.width > actualSize.width
            default:
                // For multiple lines: check if natural height exceeds actual height
                return naturalHeightSize.height > actualSize.height
        }
    }

    // MARK: - Initialization

    /// Creates a truncation-detecting text view
    /// - Parameters:
    ///   - content: The text content to display
    ///   - maxLines: Maximum number of lines (0 or nil for unlimited)
    ///   - layout: The layout this text belongs to
    ///   - strikeColor: either nil, or the color for strikethrough()
    init(_ content: String, maxLines: Int?, layout: Int, index: Int = 0, strikeColor: Color? = nil) {
        self.content = content
        self.layout = layout
        self.index = index

        self.maxLines = (maxLines ?? 0) > 0 ? maxLines : nil
        self.strikeColor = strikeColor
    }

    // MARK: - Body

    var body: some View {
        constrainedText
            .measureSize($actualSize)
            .background {
                naturalHeightText
                    .measureSize($naturalHeightSize)
                    .hidden()
            }
            .background {
                naturalWidthText
                    .measureSize($naturalWidthSize)
                    .hidden()
            }
            .overlay {
                if let isContentTruncated = isContentTruncated {
                    let value = [layout: isContentTruncated]
                    switch index {
                        case 0:
                            Color.clear
                                .preference(key: LayoutTruncationStatus0.self,
                                          value: value)
                        case 1:
                            Color.clear
                                .preference(key: LayoutTruncationStatus1.self,
                                          value: value)
                        default:
                            Color.clear
                                .preference(key: LayoutTruncationStatus2.self,
                                          value: value)
                    }
                }
            }
#if DEBUG
            .task(id: isContentTruncated) {
                if let isContentTruncated = isContentTruncated {
                    print("Layout \(layout) - Content truncated: \(isContentTruncated)")
                }
            }
#endif
    }

    // MARK: - Private Views

    @ViewBuilder
    private var constrainedText: some View {
        switch maxLines {
            case .none:
                Text(content)
                    .strikethrough(strikeColor != nil, color: strikeColor)
            default:
                Text(content)
                    .strikethrough(strikeColor != nil, color: strikeColor)
//                    .lineLimit(maxLines ?? 1, reservesSpace: true)
                    .lineLimit(maxLines ?? 1)
        }
    }

    /// Text with natural height (allows wrapping within given width)
    private var naturalHeightText: some View {
        Text(content)
            .strikethrough(strikeColor != nil, color: strikeColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Text with natural width (single line, no wrapping)
    private var naturalWidthText: some View {
        Text(content)
            .strikethrough(strikeColor != nil, color: strikeColor)
            .fixedSize(horizontal: true, vertical: false)
    }
}


// MARK: - Preference Key

/// Preference key for collecting truncation status from multiple layout modes
struct LayoutTruncationStatus0: PreferenceKey {
    static let defaultValue: [Int: Bool] = [:]

    static func reduce(
        value: inout [Int: Bool],
        nextValue: () -> [Int: Bool])
    {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct LayoutTruncationStatus1: PreferenceKey {
    static let defaultValue: [Int: Bool] = [:]

    static func reduce(
        value: inout [Int: Bool],
        nextValue: () -> [Int: Bool])
    {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct LayoutTruncationStatus2: PreferenceKey {
    static let defaultValue: [Int: Bool] = [:]

    static func reduce(
        value: inout [Int: Bool],
        nextValue: () -> [Int: Bool])
    {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - View Extensions

extension View {
    /// Measures the size of a view and binds it to the provided binding
    /// - Parameter size: A binding to store the measured size
    /// - Returns: The view with size measurement capability
    func measureSize(_ size: Binding<CGSize>) -> some View {
        background(
            GeometryReader { geometry in
                let currentSize = geometry.size
                Color.clear
                    .task(id: currentSize) {
                        size.wrappedValue = currentSize
                    }
            })
    }
}
