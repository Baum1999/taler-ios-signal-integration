/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation

extension Encodable {
    func toJSON(_ encoder: JSONEncoder = JSONEncoder()) -> String? {
        let e = encoder
        e.outputFormatting = .prettyPrinted
        if let data = try? e.encode(self) {
            let result = String(decoding: data, as: UTF8.self)
            return String(result)
        }

        return nil
    }
}
