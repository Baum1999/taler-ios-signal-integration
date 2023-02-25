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

struct HamburgerButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
        }
            .font(.title)
    }
}

struct PlusButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
            .font(.title)
    }
}

struct ArrowUpButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.to.line")
        }
        .font(.title3)
    }
}

struct ArrowDownButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.to.line")
        }
        .font(.title3)
    }
}

struct ReloadButton : View  {
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
        }
            .font(.title)
            .disabled(disabled)
    }
}

struct AwesomeButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.white)
                .background(LinearGradient(gradient: Gradient(colors: [Color.red, Color.blue]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(40)
                .font(.title)
        }
    }
}

struct Buttons_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HamburgerButton() {}
                .padding()
            PlusButton() {}
                .padding()
            HStack {
                ReloadButton(disabled: false) {}
                    .padding()
                ReloadButton(disabled: true) {}
                    .padding()
            }
            AwesomeButton(title: "AwesomeButton") {}
                .padding()
        }
    }
}
