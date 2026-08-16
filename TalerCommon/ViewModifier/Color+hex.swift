/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        let red   = Double((hex >> 16) & 0xff) / 255.0
        let green = Double((hex >> 8)  & 0xff) / 255.0
        let blue  = Double( hex        & 0xff) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
