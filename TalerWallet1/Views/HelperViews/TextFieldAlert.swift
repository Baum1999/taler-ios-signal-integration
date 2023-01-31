/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
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
            if isPresented {
                VStack {
                    Text(title).font(.headline).padding()
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
                        Spacer()
                    }
                }
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
