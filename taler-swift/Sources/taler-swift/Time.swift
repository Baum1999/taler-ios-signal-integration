/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Jonathan Buchanan
 * @author Marc Stibane
 */
import Foundation

/// Errors for `Timestamp`.
enum TimestampError: Error {
    /// The string cannot be parsed to create an `Amount`.
    case invalidStringRepresentation
    
    /// Invalid arguments were supplied to an arithmetic operation.
    case invalidArithmeticArguments

    /// The value `never` cannot be returned as UInt64.
    case invalidUInt64Value
}

public enum RelativeTime: Codable, Hashable, Sendable {
    // Duration in microseconds or "forever"
    // to represent an infinite duration. Numeric
    // values are capped at 2^53 - 1 inclusive.
    case microseconds(UInt64)
    case forever

    enum CodingKeys: String, CodingKey {
        case d_us = "d_us"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            self = RelativeTime.microseconds(try container.decode(UInt64.self, forKey: .d_us))
        } catch {       // rethrows or never
            let stringValue = try container.decode(String.self, forKey: .d_us)
            if stringValue == "forever" {
                self = RelativeTime.forever
            } else {
                throw TimestampError.invalidStringRepresentation
            }
        }
    }
    public func hash(into hasher: inout Hasher) {
        switch self {
            case .microseconds(let d_us):
                hasher.combine(d_us)
            case .forever:
                hasher.combine("forever")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var value = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .microseconds(let d_us):
                try value.encode(d_us, forKey: .d_us)
            case .forever:
                try value.encode("forever", forKey: .d_us)
        }
    }
}

extension RelativeTime {
    public func microseconds() throws -> UInt64 {
        switch self {
            case .microseconds(let d_us):
                return d_us
            case .forever:
                throw TimestampError.invalidUInt64Value
        }
    }
}
// MARK: -
/// A point in time, represented by milliseconds from January 1, 1970..
public enum Timestamp: Codable, Hashable, Sendable {
    case milliseconds(UInt64)
    case never

    enum CodingKeys: String, CodingKey {
        case t_s = "t_s"
        case t_ms = "t_ms"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            if let seconds: UInt64 = try? container.decode(UInt64.self, forKey: .t_s) {
                self = Timestamp.milliseconds(seconds * 1000)
            } else {
                self = Timestamp.milliseconds(try container.decode(UInt64.self, forKey: .t_ms))
            }
        } catch {       // rethrows or never
            let stringValue = try container.decode(String.self, forKey: .t_s)
            if stringValue == "never" {
                self = Timestamp.never
            } else {
                throw TimestampError.invalidStringRepresentation
            }
        }
    }
    public func hash(into hasher: inout Hasher) {
        switch self {
            case .milliseconds(let t_ms):
                hasher.combine(t_ms)
            case .never:
                hasher.combine("never")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var value = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .milliseconds(let t_ms):
                try value.encode(t_ms / 1000, forKey: .t_s)
            case .never:
                try value.encode("never", forKey: .t_s)
        }
    }
}

extension Timestamp: Comparable {
    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        switch lhs {
            case .milliseconds(let lhs_ms):
                switch rhs {
                    case .milliseconds(let rhs_ms):
                        return lhs_ms < rhs_ms
                    case .never: break
                }
            case .never: break
        }
        return false
    }
    public static func == (lhs: Timestamp, rhs: Timestamp) -> Bool {
        switch lhs {
            case .never:
                switch rhs {
                    case .never: return true
                    case .milliseconds(_): break
                }
            case .milliseconds(let lhs_ms):
                switch rhs {
                    case .milliseconds(let rhs_ms):
                        return lhs_ms == rhs_ms
                    case .never: break
                }
        }
        return false
    }
}

extension Timestamp {
    /// make a Timestamp for  `now`
    public static func now() -> Timestamp {
        return Timestamp.milliseconds(Date().millisecondsSince1970)
    }

    public static func tomorrow() -> Timestamp {
        return Timestamp.inSomeDays(1)
    }

    public static func inSomeDays(_ days: UInt) -> Timestamp {
        let now = Date().millisecondsSince1970
        let seconds: UInt64 = 60 * 60 * 24
        return Timestamp.milliseconds(now + (UInt64(days) * seconds * 1000))
    }

    public static func inSomeMinutes(_ minutes: UInt) -> Timestamp {
        let now = Date().millisecondsSince1970
        let seconds: UInt64 = 60
        return Timestamp.milliseconds(now + (UInt64(minutes) * seconds * 1000))
    }

    /// convenience initializer from UInt64 (milliseconds from January 1, 1970)
    public init(from: UInt64) {
        self = Timestamp.milliseconds(from)
    }

    /// switch-case the enum here so the caller function doesn't have to
    public func milliseconds() throws -> UInt64 {
        switch self {
            case .milliseconds(let t_ms):
                return t_ms
            case .never:
                throw TimestampError.invalidUInt64Value
        }
    }
}
// MARK: -
/// extend iOS Date to work with milliseconds since 1970
extension Date {
    public var millisecondsSince1970: UInt64 {
        UInt64((timeIntervalSince1970 * 1000.0).rounded())
    }

    public init(milliseconds: UInt64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
// MARK: -
/// A duration of time, measured in milliseconds.
public enum Duration: Codable, Hashable, Equatable {
    case microseconds(UInt64)
    case forever

    enum CodingKeys: String, CodingKey {
        case d_us = "d_us"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            self = Duration.microseconds(try container.decode(UInt64.self, forKey: .d_us))
        } catch {       // rethrows or never
            let stringValue = try container.decode(String.self, forKey: .d_us)
            if stringValue == "forever" {
                self = Duration.forever
            } else {
                throw TimestampError.invalidStringRepresentation
            }
        }
    }
    public func hash(into hasher: inout Hasher) {
        switch self {
            case .microseconds(let d_us):
                hasher.combine(d_us)
            case .forever:
                hasher.combine("forever")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var value = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .microseconds(let d_us):
                try value.encode(d_us, forKey: .d_us)
            case .forever:
                try value.encode("forever", forKey: .d_us)
        }
    }
}

/// Addition of a timestamp and a duration.
public func +(lhs: Timestamp, rhs: Duration) -> Timestamp {
    switch lhs {
    case .milliseconds(let lhs_ms):
        switch rhs {
        case .microseconds(let rhs_us):
            let result = lhs_ms.addingReportingOverflow(rhs_us * 1000)
            if result.overflow {
                return Timestamp.never
            } else {
                return Timestamp.milliseconds(result.partialValue)
            }
        case .forever:
            return Timestamp.never
        }
    case .never:
        return Timestamp.never
    }
}

/// Subtraction of a duration from a timestamp.
public func -(lhs: Timestamp, rhs: Duration) -> Timestamp {
    switch lhs {
    case .milliseconds(let lhs_ms):
        switch rhs {
        case .microseconds(let rhs_us):
            let result = lhs_ms.subtractingReportingOverflow(rhs_us * 1000)
            if result.overflow {
                return Timestamp.milliseconds(0)
            } else {
                return Timestamp.milliseconds(result.partialValue)
            }
        case .forever:
            return Timestamp.milliseconds(0)
        }
    case .never:
        return Timestamp.never
    }
}

/// Calculates the difference between two timestamps.
public func -(lhs: Timestamp, rhs: Timestamp) throws -> Duration {
    switch lhs {
    case .milliseconds(let lhs_ms):
        switch rhs {
        case .milliseconds(let rhs_ms):
            if lhs_ms < rhs_ms {
                return Duration.microseconds(0)
            } else {
                return Duration.microseconds((lhs_ms - rhs_ms) * 1000)
            }
        case .never:
            throw TimestampError.invalidArithmeticArguments
        }
    case .never:
        return Duration.forever
    }
}
