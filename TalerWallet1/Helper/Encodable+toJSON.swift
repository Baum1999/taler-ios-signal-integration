/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Iván Ávalos
 * @author Marc Stibane
 */
import Foundation

extension Encodable {
    func toJSON(_ encoder: JSONEncoder = JSONEncoder()) -> String? {
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(self) {
            let result = String(decoding: data, as: UTF8.self)
            return String(result)
        }
        return nil
    }
}
