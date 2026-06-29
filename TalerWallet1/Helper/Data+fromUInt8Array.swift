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

    static func clampedData(_ data: Data, offset: UInt, size: UInt) -> Data {
        let endIndex = UInt(data.endIndex)
        let start = UInt(data.startIndex) + offset
        let start2 = Swift.min(start, endIndex-1)
        let end = start2 + size
        let end2 = Swift.min(end, endIndex)
        return data[start2..<end2]
    }

    mutating func append(data: Data, offset: UInt, size: UInt) {
        self.append(Data.clampedData(data, offset: offset, size: size))
    }

    init(fromData data: Data, offset: UInt, size: UInt) {
        self.init(Data.clampedData(data, offset: offset, size: size))
    }
}
