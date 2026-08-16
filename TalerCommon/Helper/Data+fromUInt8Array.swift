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
        let count = UInt(data.count)
        // an offset at or past the end must yield nothing - clamping it to the last byte
        // would silently return unrelated data, and for empty data the clamp underflows
        guard offset < count else { return Data() }
        let start = data.startIndex + Int(offset)
        let end = start + Int(Swift.min(size, count - offset))
        return data[start..<end]
    }

    mutating func append(data: Data, offset: UInt, size: UInt) {
        self.append(Data.clampedData(data, offset: offset, size: size))
    }

    init(fromData data: Data, offset: UInt, size: UInt) {
        self.init(Data.clampedData(data, offset: offset, size: size))
    }
}
