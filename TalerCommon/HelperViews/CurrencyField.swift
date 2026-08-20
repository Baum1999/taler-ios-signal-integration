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
    let currencyInfo: CurrencyInfo
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

    public init(_ currencyInfo: CurrencyInfo, amount: Binding<Amount>, handle: CurrencyFieldHandle) {
        self._amount = amount
        self.currencyInfo = currencyInfo
        self.currencyFieldRepresentable =
                CurrencyTextfieldRepresentable(currencyInfo: self.currencyInfo,
                                                     amount: self.$amount,
                                                     handle: handle)
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(amount.description)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        ZStack {
            // Text view to display the formatted currency
            // Set as priority so CurrencyInputField size doesn't affect parent
            let formatted = amount.formatted(currencyInfo, isNegative: false)
            let text = Text(formatted.0)
                        .accessibilityLabel(formatted.1)
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
    /// The text as it was last set from an `Amount´. `Coordinator.editingChanged´ diffs
    /// the field's text against it to find the newly typed digit, so the two must never
    /// be set independently - always use `setPlainText´ for both.
    fileprivate var lastValidInput: String? = EMPTYSTRING

    /// Set both the displayed text and the last valid input, caret at the end.
    fileprivate func setPlainText(_ plain: String?) {
        lastValidInput = plain
//        print("Setting textfield to: \(plain)")
        text = plain
        let endPosition = endOfDocument
        selectedTextRange = textRange(from: endPosition, to: endPosition)
    }

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
/// SwiftUI re-creates `CurrencyField´ and its `UIViewRepresentable´ on every body pass,
/// but calls `makeUIView´ only once. The view which shows the field keeps this box in
/// `@State´, so it survives those passes and always refers to the text field which
/// really is in the view hierarchy.
final class CurrencyFieldHandle {
    fileprivate weak var textField: NoCaretTextField? = nil
}
// MARK: -
@MainActor
struct CurrencyTextfieldRepresentable: UIViewRepresentable {
    let currencyInfo: CurrencyInfo
    @Binding var amount: Amount
    let handle: CurrencyFieldHandle

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor public func becomeFirstResponder() -> Bool {
        guard let textField = handle.textField else { return false }
        return textField.becomeFirstResponder()
    }

    @MainActor public func resignFirstResponder() {
        handle.textField?.resignFirstResponder()
        Self.endEditing()
    }

    func updateText(amount: Amount) {
        handle.textField?.setPlainText(amount.plainString(currencyInfo))
    }

    func toolBar(for textField: UITextField) -> UIToolbar {
        let image = UIImage(systemName: RETURN)   // 􀅇
        let button = UIBarButtonItem(image: image, style: .done, target: textField,
                                    action: #selector(UITextField.resignFirstResponder))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace,
                                                     target: self, action: nil)
        let toolBar: UIToolbar = UIToolbar()
        toolBar.items = [flexSpace, button]

        // Unable to simultaneously satisfy constraints
        // Will attempt to recover by breaking constraint
        // <NSLayoutConstraint: UIImageView: .centerY == _UIModernBarButton: .centerY   (active)>

        // this all doesn't help
//        toolBar.frame.size.height = 100
//        toolBar.autoresizingMask = .flexibleWidth
//        toolBar.translatesAutoresizingMaskIntoConstraints = false
        toolBar.sizeToFit()
        return toolBar
    }

    func makeUIView(context: Context) -> NoCaretTextField {
        // the view hierarchy owns the field, `handle´ only points to it
        let textField = NoCaretTextField(frame: .zero)
        handle.textField = textField
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Assign delegate
        textField.delegate = context.coordinator

        // Set keyboard type
        textField.keyboardType = .asciiCapableNumberPad //  numberPad decimalPad phonePad numbersAndPunctuation

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

        // Add a toolbar with a done button above the keyboard
        textField.inputAccessoryView = toolBar(for: textField)

        // Set initial textfield text
        textField.setPlainText(amount.plainString(currencyInfo))

        return textField
    }

    func updateUIView(_ uiView: NoCaretTextField, context: Context) {
        // the coordinator captured an older copy of this struct - refresh it
        context.coordinator.textfieldRepresentable = self
        // reconcile the field with the `value´, e.g. after a shortcut button was tapped
        let plain = amount.plainString(currencyInfo)
        if uiView.lastValidInput != plain {
            uiView.setPlainText(plain)
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        // Reference to currency input field
        fileprivate var textfieldRepresentable: CurrencyTextfieldRepresentable

        init(_ representable: CurrencyTextfieldRepresentable) {
            self.textfieldRepresentable = representable
        }

        func setValue(_ amount: Amount) {
            // Update hidden textfield text
            updateText(amount)
            // Update input value
//    print(input.amount.description, " := ", amount.description)
            textfieldRepresentable.amount = amount
        }

        func updateText(_ amount: Amount) {
            // Update field text and last valid input text
            let plain = amount.plainString(textfieldRepresentable.currencyInfo)
//    print("lastValidInput: `\(plain)´")
            textfieldRepresentable.handle.textField?.setPlainText(plain)
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
                    setValue(amount)
                }
                // We already applied (or intentionally skipped) the edit ourselves above -
                // returning true here would let UIKit apply its own, now-stale range edit
                // on top of what setPlainText just set, desyncing text from lastValidInput.
                return false
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
            // Get a mutable copy of last text - from the field which sent this event,
            // so that it can never be out of sync with the text we compare it against
            guard var oldText = textField.lastValidInput else {
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
                textField.text = textField.lastValidInput
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
            setValue(amount)
        }
    }
}
