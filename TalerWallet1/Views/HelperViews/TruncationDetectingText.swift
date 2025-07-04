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
 *      added strikethrough, more compact modes
 */
import SwiftUI

//@available(iOS 16.0, *)
struct TruncationDetectingText: View {
    // MARK: - Properties

    private let content: String
    private let maxLines: Int?
    private let layoutMode: LayoutMode
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
    ///   - maxLines: Maximum number of lines (nil for unlimited)
    ///   - layoutMode: The layout mode this text belongs to
    init(_ content: String, maxLines: Int?, layoutMode: LayoutMode, strikeColor: Color? = nil) {
        self.content = content
        self.layoutMode = layoutMode

        if let maxLines = maxLines, maxLines <= 0 {
            fatalError("maxLines cannot be less than or equal to 0")
        }

        self.maxLines = maxLines
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
                    Color.clear
                        .preference(
                            key: LayoutTruncationStatus.self,
                            value: [layoutMode: isContentTruncated])
                }
            }
#if DEBUG
            .task(id: isContentTruncated) {
                if let isContentTruncated = isContentTruncated {
                    print("Layout \(layoutMode.description) - Content truncated: \(isContentTruncated)")
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

// MARK: - Layout Mode

/// Represents different layout modes for amount rows
enum LayoutMode: Int, Hashable, Identifiable, CaseIterable {
    case compact1 // Single line horizontal layout
    case compact2 // Single line horizontal layout
    case compact3 // Single line horizontal layout
    case compact4 // Single line horizontal layout
    case standard // Two-line horizontal layout
    case extended // Vertical layout

    var id: Self { self }
}

// MARK: - Layout Mode Extensions

extension LayoutMode: Comparable {
    static func < (lhs: LayoutMode, rhs: LayoutMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension LayoutMode: CustomStringConvertible {
    var description: String {
        switch self {
            case .compact1: "compact1"
            case .compact2: "compact2"
            case .compact3: "compact3"
            case .compact4: "compact3"
            case .standard: "standard"
            case .extended: "extended"
        }
    }
}

// MARK: - Preference Key

/// Preference key for collecting truncation status from multiple layout modes
struct LayoutTruncationStatus: PreferenceKey {
    static var defaultValue: [LayoutMode: Bool] = [:]

    static func reduce(
        value: inout [LayoutMode: Bool],
        nextValue: () -> [LayoutMode: Bool])
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
