import Foundation

/// Exact fraction. Score positions and durations are fractions of a whole note (a quarter note is 1/4).
public struct Rational: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let n: Int64
    public let d: Int64

    public init(_ n: Int64, _ d: Int64 = 1) {
        precondition(d != 0, "Rational with zero denominator")
        let g = Rational.gcd(abs(n), abs(d))
        let sign: Int64 = d < 0 ? -1 : 1
        self.n = sign * n / max(g, 1)
        self.d = sign * d / max(g, 1)
    }

    public init(_ n: Int, _ d: Int = 1) { self.init(Int64(n), Int64(d)) }

    public static let zero = Rational(Int64(0), 1)

    static func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        var (x, y) = (a, b)
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    public static func + (a: Rational, b: Rational) -> Rational { Rational(a.n * b.d + b.n * a.d, a.d * b.d) }
    public static func - (a: Rational, b: Rational) -> Rational { Rational(a.n * b.d - b.n * a.d, a.d * b.d) }
    public static func * (a: Rational, b: Rational) -> Rational { Rational(a.n * b.n, a.d * b.d) }
    public static func / (a: Rational, b: Rational) -> Rational { Rational(a.n * b.d, a.d * b.n) }
    public static func < (a: Rational, b: Rational) -> Bool { a.n * b.d < b.n * a.d }
    public static func += (a: inout Rational, b: Rational) { a = a + b }

    public var doubleValue: Double { Double(n) / Double(d) }
    public var description: String { d == 1 ? "\(n)" : "\(n)/\(d)" }

    /// Rounds to the nearest integer, half to even.
    public var rounded: Int64 {
        let q = n / d, r = n % d
        let twice = abs(r) * 2
        if twice < d { return q }
        let away = n >= 0 ? q + 1 : q - 1
        if twice > d { return away }
        return q % 2 == 0 ? q : away
    }
}
