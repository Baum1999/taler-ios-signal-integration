//  MIT License
//  Copyright Codelaby https://stackoverflow.com/users/3464919/codelaby
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
import Foundation
import SwiftUI
import Combine

public extension View {
    /// Sets an environment value for keyboardShowing
    /// Access this in any child view with
    /// @Environment(\.keyboardShowing) var keyboardShowing
    func addKeyboardVisibilityToEnvironment() -> some View {
        modifier(KeyboardVisibility())
    }
}

private struct KeyboardShowingEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var keyboardShowing: Bool {
        get { self[KeyboardShowingEnvironmentKey.self] }
        set { self[KeyboardShowingEnvironmentKey.self] = newValue }
    }
}

private final class KeyboardMonitor: ObservableObject {
    @Published var isKeyboardShowing: Bool = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
            .assign(to: \.isKeyboardShowing, on: self)
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }
            .assign(to: \.isKeyboardShowing, on: self)
            .store(in: &cancellables)
    }
}

private struct KeyboardVisibility: ViewModifier {
    @StateObject private var keyboardMonitor = KeyboardMonitor()

    fileprivate func body(content: Content) -> some View {
        content
            .environment(\.keyboardShowing, keyboardMonitor.isKeyboardShowing)
    }
}

//  Usage
//  App
//      WindowGroup {
//          ContentView()
//              .addKeyboardVisibilityToEnvironment()
//
//  View
//      @Environment(\.keyboardShowing) var keyboardShowing
//      ...
//      Text("Keyboard present: \(keyboardShowing.description)" )
