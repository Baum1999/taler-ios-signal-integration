/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

struct TextFieldAlert: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let doneText: String
    @Binding var text: String
    let placeholder: String
    let action: (String) -> Void
    func body(content: Content) -> some View {
        ZStack(alignment: .center) {
            content
                .disabled(isPresented)
                .accessibilityElement(children: isPresented ? .ignore : .contain)
            if isPresented {
                VStack {
                    Text(title)
                        .talerFont(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityRemoveTraits(.isStaticText)
                        .padding()
                    TextField(placeholder, text: $text).textFieldStyle(.roundedBorder).padding()
                    Divider()
                    HStack {
                        Spacer()
                        Button(role: .cancel) {
                            withAnimation { isPresented.toggle() }
                        } label: {
                            Text("Cancel")
                        }
                        Spacer()
                        Divider()
                        Spacer()
                        Button(doneText) {
                            action(text)
                            withAnimation { isPresented.toggle() }
                        }
//                        .talerFont(.talerBody)     TODO: check
                        Spacer()
                    }
                }
                    .accessibility(addTraits: .isModal)
                    .background(.background)
                    .frame(width: 300, height: 200)
                    .cornerRadius(20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.quaternary, lineWidth: 1)
                    }
            }
        }
    }
}

extension View {
    public func textFieldAlert(isPresented: Binding<Bool>,
                                     title: String,
                                  doneText: String,
                                      text: Binding<String>,
                               placeholder: String = "",
                                    action: @escaping (String) -> Void
    ) -> some View {
        self.modifier(TextFieldAlert(isPresented: isPresented, title: title, doneText: doneText, text: text, placeholder: placeholder, action: action))
    }
}
