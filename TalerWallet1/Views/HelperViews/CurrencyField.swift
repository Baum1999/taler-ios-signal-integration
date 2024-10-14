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
/**
 * @author Marc Stibane
 */
import SwiftUI
import UIKit
import taler_swift
import SymLog

@MainActor
struct CurrencyField: View {
    private let symLog = SymLogV(0)
    @Binding var currencyInfo: CurrencyInfo
    @Binding var amount: Amount         // the `value´

    private var currencyFieldRepresentable: CurrencyTextfieldRepresentable! = nil

    public func becomeFirstResponder() -> Bool {
        currencyFieldRepresentable.becomeFirstResponder()
    }

    public func resignFirstResponder() -> Void {
        currencyFieldRepresentable.resignFirstResponder()
    }

    func updateText(amount: Amount) {
        currencyFieldRepresentable.updateText(amount: amount)
    }

    public init(_ currencyInfo: Binding<CurrencyInfo>, amount: Binding<Amount>) {
        self._amount = amount
        self._currencyInfo = currencyInfo
        self.currencyFieldRepresentable =
                CurrencyTextfieldRepresentable(currencyInfo: self.$currencyInfo,
                                                     amount: self.$amount)
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(amount.description)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        ZStack {
            // Text view to display the formatted currency
            // Set as priority so CurrencyInputField size doesn't affect parent
            let text = Text(amount.formatted(currencyInfo, isNegative: false))
                        .layoutPriority(1)
            // make the textfield use the whole width for tapping inside to become active
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(4)
            text
                .accessibilityHidden(true)
                .background(WalletColors().fieldBackground)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(WalletColors().fieldForeground, lineWidth: 1))
            // Input text field to handle UI
            currencyFieldRepresentable
        }
    }
}
// MARK: -
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
// MARK: -
@MainActor
struct CurrencyTextfieldRepresentable: UIViewRepresentable {
    @Binding var currencyInfo: CurrencyInfo
    @Binding var amount: Amount

    private let textField = NoCaretTextField(frame: .zero)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor public func becomeFirstResponder() -> Bool {
        textField.becomeFirstResponder()
    }

    @MainActor public func resignFirstResponder() -> Void {
        textField.resignFirstResponder()
        Self.endEditing()
    }

    func updateText(amount: Amount) {
        let plain = amount.plainString(currencyInfo)
        print("Setting textfield to: \(plain)")
        textField.text = plain
        let endPosition = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: endPosition, to: endPosition)
    }

    func makeUIView(context: Context) -> NoCaretTextField {
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Assign delegate
        textField.delegate = context.coordinator

        // Set keyboard type
        textField.keyboardType = .asciiCapableNumberPad //  numberPad

        // Make visual components invisible...
        textField.tintColor = .clear
        textField.textColor = .clear
        textField.backgroundColor = .clear
        // ... except for the bezel around the textfield
        textField.borderStyle = .none   // .roundedRect
//        textField.textFieldStyle(.roundedBorder)

#if DEBUG
        // Debugging: add a red border around the textfield
        let myColor = UIColor(red: 0.9, green: 0.1, blue:0, alpha: 1.0)
        textField.layer.masksToBounds = true
        textField.layer.borderColor = myColor.cgColor
    //    textField.layer.borderWidth = 2.0      //    <-   uncomment to show the border
#endif
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
        private var textfieldRepresentable: CurrencyTextfieldRepresentable

        // Last valid text input string to be displayed
        private var lastValidInput: String? = EMPTYSTRING

        init(_ representable: CurrencyTextfieldRepresentable) {
            self.textfieldRepresentable = representable
        }

        func setValue(_ amount: Amount, textField: UITextField) {
            // Update hidden textfield text
            updateText(amount, textField: textField)
            // Update input value
//    print(input.amount.description, " := ", amount.description)
            textfieldRepresentable.amount = amount
        }

        func updateText(_ amount: Amount, textField: UITextField) {
            // Update field text and last valid input text
            lastValidInput = amount.plainString(textfieldRepresentable.currencyInfo)
//    print("lastValidInput: `\(lastValidInput)´")
            textField.text = lastValidInput
            let endPosition = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: endPosition, to: endPosition)
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // If replacement string is empty, we can assume the backspace key was hit
            if string.isEmpty {
                // Resign first responder when delete is hit when value is 0
                if textfieldRepresentable.amount.isZero {
                    textField.resignFirstResponder()
//                    Self.endEditing()
                } else {
                    // Remove trailing digit: divide value by 10
                    let amount = textfieldRepresentable.amount.copy()
                    amount.removeDigit(textfieldRepresentable.currencyInfo)
                    setValue(amount, textField: textField)
                }
            }
            return true
        }

        func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
            return true
        }

        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            return true
        }

        @objc func editingChanged(textField: NoCaretTextField) {
            // Get a mutable copy of last text
            guard var oldText = lastValidInput else {
                return
            }

            // Iterate through each char of the new string and compare LTR with old string
            let char = (textField.text ?? EMPTYSTRING).first { next in
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
            let amount = textfieldRepresentable.amount.copy()
            amount.addDigit(digit, currencyInfo: textfieldRepresentable.currencyInfo)

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
