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
import Foundation

/// Errors for `Timestamp`.
enum TimestampError: Error {
    /// The string cannot be parsed to create an `Amount`.
    case invalidStringRepresentation
    
    /// Invalid arguments were supplied to an arithmetic operation.
    case invalidArithmeticArguments
}

/// A point in time, represented by milliseconds from Jaunuary 1, 1970..
public enum Timestamp: Codable, Equatable {
    case milliseconds(UInt64)
    case never
    
    enum CodingKeys: String, CodingKey {
        case t_ms = "t_ms"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            self = Timestamp.milliseconds(try container.decode(UInt64.self, forKey: .t_ms))
        } catch {
            let stringValue = try container.decode(String.self, forKey: .t_ms)
            if stringValue == "never" {
                self = Timestamp.never
            } else {
                throw TimestampError.invalidStringRepresentation
            }
        }
    }
    
    static func now() -> Timestamp {
        return Timestamp.milliseconds(UInt64(Date().timeIntervalSince1970 * 1000.0))
    }
    
    public func encode(to encoder: Encoder) throws {
        var value = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .milliseconds(let t_ms):
            try value.encode(t_ms, forKey: .t_ms)
        case .never:
            try value.encode("never", forKey: .t_ms)
        }
    }
}

/// A duration of time, measured in milliseconds.
public enum Duration: Equatable {
    case milliseconds(UInt64)
    case forever
}

/// Addition of a timestamp and a duration.
func +(lhs: Timestamp, rhs: Duration) -> Timestamp {
    switch lhs {
    case .milliseconds(let lhs_ms):
        switch rhs {
        case .milliseconds(let rhs_ms):
            let result = lhs_ms.addingReportingOverflow(rhs_ms)
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
func -(lhs: Timestamp, rhs: Duration) -> Timestamp {
    switch lhs {
    case .milliseconds(let lhs_ms):
        switch rhs {
        case .milliseconds(let rhs_ms):
            let result = lhs_ms.subtractingReportingOverflow(rhs_ms)
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
func -(lhs: Timestamp, rhs: Timestamp) throws -> Duration {
    switch lhs {
    case .milliseconds(let lhs_ms):
        switch rhs {
        case .milliseconds(let rhs_ms):
            if lhs_ms < rhs_ms {
                return Duration.milliseconds(0)
            } else {
                return Duration.milliseconds(lhs_ms - rhs_ms)
            }
        case .never:
            throw TimestampError.invalidArithmeticArguments
        }
    case .never:
        return Duration.forever
    }
}
