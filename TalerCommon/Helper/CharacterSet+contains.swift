/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

public extension CharacterSet {

    func contains(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(contains)
    }

    func containsAll(in string: String) -> Bool {
        string.unicodeScalars.allSatisfy(contains)
    }
}

public extension CharacterSet {

    static func + (lhs: CharacterSet, rhs: CharacterSet) -> CharacterSet {
        lhs.union(rhs)
    }

    static func - (lhs: CharacterSet, rhs: CharacterSet) -> CharacterSet {
        lhs.subtracting(rhs)
    }
}
