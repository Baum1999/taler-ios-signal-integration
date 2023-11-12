/* MIT License
 * Copyright (c) 2022 Javier Trinchero
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
import UIKit
import taler_swift
import SymLog

@MainActor
struct CurrencyField: View {
    private let symLog = SymLogV(0)
    @Binding var amount: Amount         // the `value´
    let currencyInfo: CurrencyInfo

    private var currencyInputField: CurrencyInputField! = nil

    public func becomeFirstResponder() -> Void {
        currencyInputField.becomeFirstResponder()
    }

    public func resignFirstResponder() -> Void {
        currencyInputField.resignFirstResponder()
    }

    public init(amount: Binding<Amount>, currencyInfo: CurrencyInfo) {
        self._amount = amount
        self.currencyInfo = currencyInfo
        self.currencyInputField = CurrencyInputField(amount: self.$amount,
                                               currencyInfo: currencyInfo)
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog(amount.description)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        ZStack {
            // Text view to display the formatted currency
            // Set as priority so CurrencyInputField size doesn't affect parent
            Text(amount.string(currencyInfo))
                .layoutPriority(1)

            // Input text field to handle UI
            currencyInputField
//                .textFieldStyle(.roundedBorder)
        }
    }
}

// Sub-class UITextField to remove selection and caret
class NoCaretTextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }

    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        []
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        .null
    }
}

@MainActor
struct CurrencyInputField: UIViewRepresentable {
    @Binding var amount: Amount
    let currencyInfo: CurrencyInfo
    private let textField = NoCaretTextField(frame: .zero)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor public func becomeFirstResponder() -> Void {
        textField.becomeFirstResponder()
    }

    @MainActor public func resignFirstResponder() -> Void {
        textField.resignFirstResponder()
    }

    func makeUIView(context: Context) -> NoCaretTextField {
        // Assign delegate
        textField.delegate = context.coordinator

        // Set keyboard type
        textField.keyboardType = .numberPad

        // Make visual components invisible
        textField.tintColor = .clear
        textField.textColor = .clear
        textField.backgroundColor = .clear

        // Add editingChanged event handler
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(textField:)),
            for: .editingChanged
        )

        // Set initial textfield text
        context.coordinator.updateText(amount, textField: textField)

        return textField
    }

    func updateUIView(_ uiView: NoCaretTextField, context: Context) {}

    class Coordinator: NSObject, UITextFieldDelegate {
        // Reference to currency input field
        private var input: CurrencyInputField

        // Last valid text input string to be displayed
        private var lastValidInput: String? = ""

        init(_ currencyTextField: CurrencyInputField) {
            self.input = currencyTextField
        }

        func setValue(_ amount: Amount, textField: UITextField) {
            // Update hidden textfield text
            updateText(amount, textField: textField)
            // Update input value
//    print(input.amount.description, " := ", amount.description)
            input.amount = amount
        }

        func updateText(_ amount: Amount, textField: UITextField) {
            // Update field text and last valid input text
            lastValidInput = amount.plainString(input.currencyInfo)
//    print(lastValidInput)
            textField.text = lastValidInput
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // If replacement string is empty, we can assume the backspace key was hit
            if string.isEmpty {
                // Resign first responder when delete is hit when value is 0
                if input.amount.isZero {
                    textField.resignFirstResponder()
                } else {
                    // Remove trailing digit: divide value by 10
                    let amount = input.amount.copy()
                    amount.removeDigit(input.currencyInfo)
                    setValue(amount, textField: textField)
                }
            }
            return true
        }

        @objc func editingChanged(textField: NoCaretTextField) {
            // Get a mutable copy of last text
            guard var oldText = lastValidInput else {
                return
            }

            // Iterate through each char of the new string and compare LTR with old string
            let char = (textField.text ?? "").first { next in
                // If old text is empty or its next character doesn't match new
                if oldText.isEmpty || next != oldText.removeFirst() {
                    // Found the mismatching character
                    return true
                }
                return false
            }

            // Find new character and try to get an Int value from it
            guard let char, let digit = UInt8(String(char)), digit <= 9 else {
                // New character could not be converted to Int
                // Revert to last valid text
                textField.text = lastValidInput
                return
            }

            // Multiply by 10 to shift numbers one position to the left, revert if an overflow occurs
            // Add the new trailing digit, revert if an overflow occurs
            let amount = input.amount.copy()
            amount.addDigit(digit, currencyInfo: input.currencyInfo)

            // If new value has more digits than allowed by formatter, revert
//            if input.formatter.maximumFractionDigits + input.formatter.maximumIntegerDigits < String(addValue).count {
//                textField.text = lastValidInput
//                return
//            }

            // Update new value
            setValue(amount, textField: textField)
        }
    }
}
