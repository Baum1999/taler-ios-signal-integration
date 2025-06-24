/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

extension Data {
    init(fromUInt8Array inValues: [UInt8]) {
        let values = inValues
        self.init(bytes: values, count: values.count)
    }

    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined()
    }

    mutating func append(data: Data, offset: Int, size: Int) {
        let start = data.startIndex + offset
        let end = start + size
        self.append(data[start..<end])
    }

    init(fromData data: Data, offset: Int, size: Int) {
        let start = data.startIndex + offset
        let end = start + size
        self.init(data[start..<end])
    }
}
