/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

func SuperScriptDigits(_ number: String) -> String {
    var result = EMPTYSTRING
    for char in number {
        switch char {
            case "0": result = result + String("\u{2070}")
            case "1": result = result + String("\u{00B9}")
            case "2": result = result + String("\u{00B2}")
            case "3": result = result + String("\u{00B3}")
            case "4": result = result + String("\u{2074}")
            case "5": result = result + String("\u{2075}")
            case "6": result = result + String("\u{2076}")
            case "7": result = result + String("\u{2077}")
            case "8": result = result + String("\u{2078}")
            case "9": result = result + String("\u{2079}")
            default: result = result + String(char)
        }
    }
    return result
}
