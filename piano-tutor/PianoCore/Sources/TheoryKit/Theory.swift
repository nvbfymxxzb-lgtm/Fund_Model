import Foundation
import MusicModel

/// A note name without an octave, such as F♯.
public struct NoteName: Hashable, Codable, Sendable, CustomStringConvertible {
    public var step: Step
    public var alter: Int
    public init(_ step: Step, _ alter: Int = 0) { self.step = step; self.alter = alter }

    public init?(_ text: String) {
        guard let p = SpelledPitch(text + "4") else { return nil }
        self.init(p.step, p.alter)
    }

    public var pitchClass: Int { ((step.semitones + alter) % 12 + 12) % 12 }
    public var description: String { step.letter + SpelledPitch.accidentalText(alter) }
    /// Plain-text form used in content files, such as "F#" or "Bb".
    public var ascii: String { step.letter + (alter > 0 ? String(repeating: "#", count: alter) : String(repeating: "b", count: -alter)) }

    /// The note a given number of letters and semitones above this one, spelled correctly.
    public func up(letters: Int, semitones: Int) -> NoteName {
        let target = step.advanced(by: letters).step
        var alter = (pitchClass + semitones) - target.semitones
        while alter > 6 { alter -= 12 }
        while alter < -6 { alter += 12 }
        return NoteName(target, alter)
    }
}

public enum ScaleType: String, Codable, CaseIterable, Sendable {
    case major, naturalMinor, harmonicMinor, melodicMinor

    public var steps: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor: return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        }
    }
    public var title: String {
        switch self {
        case .major: return "major"
        case .naturalMinor: return "natural minor"
        case .harmonicMinor: return "harmonic minor"
        case .melodicMinor: return "melodic minor"
        }
    }
}

public enum ChordQuality: String, Codable, CaseIterable, Sendable {
    case major, minor, diminished, augmented, dominant7, major7, minor7, halfDiminished7, diminished7

    /// Semitones above the root for the third, fifth and (if any) seventh.
    public var intervals: [Int] {
        switch self {
        case .major: return [4, 7]
        case .minor: return [3, 7]
        case .diminished: return [3, 6]
        case .augmented: return [4, 8]
        case .dominant7: return [4, 7, 10]
        case .major7: return [4, 7, 11]
        case .minor7: return [3, 7, 10]
        case .halfDiminished7: return [3, 6, 10]
        case .diminished7: return [3, 6, 9]
        }
    }
    public var symbolSuffix: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "dim"
        case .augmented: return "aug"
        case .dominant7: return "7"
        case .major7: return "maj7"
        case .minor7: return "m7"
        case .halfDiminished7: return "m7♭5"
        case .diminished7: return "dim7"
        }
    }
    public var title: String {
        switch self {
        case .major: return "major"
        case .minor: return "minor"
        case .diminished: return "diminished"
        case .augmented: return "augmented"
        case .dominant7: return "dominant seventh"
        case .major7: return "major seventh"
        case .minor7: return "minor seventh"
        case .halfDiminished7: return "half-diminished seventh"
        case .diminished7: return "diminished seventh"
        }
    }
    public var isSeventh: Bool { intervals.count == 3 }
}

public struct ChordSpec: Hashable, Codable, Sendable {
    public var root: String            // "C", "F#", "Bb"
    public var quality: ChordQuality
    public var inversion: Int          // 0 root position, 1 first inversion…

    public init(root: String, quality: ChordQuality = .major, inversion: Int = 0) {
        self.root = root; self.quality = quality; self.inversion = inversion
    }

    public var rootName: NoteName { NoteName(root) ?? NoteName(.c) }

    /// Chord tones from the root up, correctly spelled.
    public var tones: [NoteName] {
        var result = [rootName]
        for (i, semis) in quality.intervals.enumerated() { result.append(rootName.up(letters: 2 * (i + 1), semitones: semis)) }
        return result
    }
    public var pitchClasses: Set<Int> { Set(tones.map { $0.pitchClass }) }
    public var bass: NoteName { tones[min(inversion, tones.count - 1)] }
    public var symbol: String {
        let base = rootName.description + quality.symbolSuffix
        return inversion == 0 ? base : "\(base)/\(bass)"
    }
    public var inversionName: String {
        ["root position", "first inversion", "second inversion", "third inversion"][min(inversion, 3)]
    }
    public var title: String { "\(rootName) \(quality.title)" }

    /// The chord in close position with its bass note at or above `lowest`.
    public func pitches(above lowest: Int = 48) -> [SpelledPitch] {
        let order = Array(tones[min(inversion, tones.count - 1)...] + tones[..<min(inversion, tones.count - 1)])
        var result: [SpelledPitch] = []
        var floor = lowest
        for name in order {
            var octave = floor / 12 - 2
            var p = SpelledPitch(step: name.step, alter: name.alter, octave: octave)
            while p.midi < floor { octave += 1; p = SpelledPitch(step: name.step, alter: name.alter, octave: octave) }
            result.append(p)
            floor = p.midi + 1
        }
        return result
    }
}

public enum Theory {
    public static let sharpOrder: [NoteName] = [NoteName(.f, 1), NoteName(.c, 1), NoteName(.g, 1), NoteName(.d, 1), NoteName(.a, 1), NoteName(.e, 1), NoteName(.b, 1)]
    public static let flatOrder: [NoteName] = [NoteName(.b, -1), NoteName(.e, -1), NoteName(.a, -1), NoteName(.d, -1), NoteName(.g, -1), NoteName(.c, -1), NoteName(.f, -1)]

    /// The seven notes of a scale plus the octave, correctly spelled.
    public static func scale(_ tonic: NoteName, _ type: ScaleType) -> [NoteName] {
        (0...7).map { i in tonic.up(letters: i, semitones: i == 7 ? 12 : type.steps[i]) }
    }

    /// The scale as pitches rising from the tonic nearest above `lowest`.
    public static func scalePitches(_ tonic: NoteName, _ type: ScaleType, from lowest: Int = 60, octaves: Int = 1) -> [SpelledPitch] {
        var start = SpelledPitch(step: tonic.step, alter: tonic.alter, octave: lowest / 12 - 2)
        while start.midi < lowest { start.octave += 1 }
        var result: [SpelledPitch] = []
        for o in 0..<octaves {
            for i in 0..<7 {
                let name = tonic.up(letters: i, semitones: type.steps[i])
                let (_, wraps) = tonic.step.advanced(by: i)
                result.append(SpelledPitch(step: name.step, alter: name.alter, octave: start.octave + o + wraps))
            }
        }
        result.append(SpelledPitch(step: tonic.step, alter: tonic.alter, octave: start.octave + octaves))
        return result
    }

    /// Number of sharps (positive) or flats (negative) for a major key.
    public static func fifths(majorTonic tonic: NoteName) -> Int {
        let letterFifths: [Step: Int] = [.c: 0, .g: 1, .d: 2, .a: 3, .e: 4, .b: 5, .f: -1]
        return (letterFifths[tonic.step] ?? 0) + 7 * tonic.alter
    }
    public static func fifths(minorTonic tonic: NoteName) -> Int { fifths(majorTonic: tonic.up(letters: 2, semitones: 3)) }

    public static func majorTonic(fifths: Int) -> NoteName {
        var n = NoteName(.c)
        if fifths > 0 { for _ in 0..<fifths { n = n.up(letters: 4, semitones: 7) } }
        if fifths < 0 { for _ in 0..<(-fifths) { n = n.up(letters: 3, semitones: 5) } }
        return n
    }
    public static func minorTonic(fifths: Int) -> NoteName { majorTonic(fifths: fifths).up(letters: 5, semitones: 9) }

    public static func signature(fifths: Int) -> [NoteName] {
        fifths >= 0 ? Array(sharpOrder.prefix(fifths)) : Array(flatOrder.prefix(-fifths))
    }

    public static func keyName(fifths: Int, minor: Bool) -> String {
        minor ? "\(minorTonic(fifths: fifths)) minor" : "\(majorTonic(fifths: fifths)) major"
    }

    /// The chord built on a scale degree (1–7). Minor keys use the harmonic minor, so V is major.
    public static func diatonicTriad(degree: Int, tonic: NoteName, minor: Bool) -> ChordSpec {
        let notes = scale(tonic, minor ? .harmonicMinor : .major)
        let i = (degree - 1) % 7
        let root = notes[i], third = notes[(i + 2) % 7], fifth = notes[(i + 4) % 7]
        let t = ((third.pitchClass - root.pitchClass) + 12) % 12, f = ((fifth.pitchClass - root.pitchClass) + 12) % 12
        let quality: ChordQuality = t == 4 ? (f == 8 ? .augmented : .major) : (f == 6 ? .diminished : .minor)
        return ChordSpec(root: root.ascii, quality: quality)
    }

    public static func roman(degree: Int, quality: ChordQuality) -> String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
        let base = numerals[(degree - 1) % 7]
        switch quality {
        case .major: return base
        case .minor: return base.lowercased()
        case .diminished: return base.lowercased() + "°"
        case .augmented: return base + "+"
        case .dominant7: return base + "7"
        case .major7: return base + "maj7"
        case .minor7: return base.lowercased() + "7"
        case .halfDiminished7: return base.lowercased() + "ø7"
        case .diminished7: return base.lowercased() + "°7"
        }
    }

    /// Name of the interval from a lower note up to a higher one, such as "major third".
    public static func intervalName(from low: SpelledPitch, to high: SpelledPitch) -> String {
        let letters = (high.octave * 7 + high.step.rawValue) - (low.octave * 7 + low.step.rawValue)
        let semitones = high.midi - low.midi
        let simple = letters % 7
        let reference = [0, 2, 4, 5, 7, 9, 11][simple] + 12 * (letters / 7)
        let diff = semitones - reference
        let perfect = [0, 3, 4].contains(simple)
        let quality: String
        if perfect {
            quality = diff == 0 ? "perfect" : (diff == 1 ? "augmented" : (diff == -1 ? "diminished" : "altered"))
        } else {
            quality = diff == 0 ? "major" : (diff == -1 ? "minor" : (diff == 1 ? "augmented" : (diff == -2 ? "diminished" : "altered")))
        }
        let names = ["unison", "second", "third", "fourth", "fifth", "sixth", "seventh", "octave", "ninth", "tenth"]
        let number = letters < names.count ? names[letters] : "\(letters + 1)th"
        return "\(quality) \(number)"
    }

    public static let intervalNamesBySemitones = ["unison", "minor second", "major second", "minor third", "major third", "perfect fourth",
                                                  "tritone", "perfect fifth", "minor sixth", "major sixth", "minor seventh", "major seventh", "octave"]

    /// Standard one-octave fingering for a scale, rising. Returns nil where the app has no reference fingering.
    /// These are the fingerings commonly printed in scale manuals; check them against your own reference.
    public static func scaleFingering(tonic: NoteName, type: ScaleType, hand: Hand) -> [Int]? {
        let table: [String: (rh: [Int], lh: [Int])] = [
            "C": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "G": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "D": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "A": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "E": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "B": ([1, 2, 3, 1, 2, 3, 4, 5], [4, 3, 2, 1, 4, 3, 2, 1]),
            "F": ([1, 2, 3, 4, 1, 2, 3, 4], [5, 4, 3, 2, 1, 3, 2, 1]),
            "Bb": ([2, 1, 2, 3, 1, 2, 3, 4], [3, 2, 1, 4, 3, 2, 1, 3]),
            "Eb": ([3, 1, 2, 3, 4, 1, 2, 3], [3, 2, 1, 4, 3, 2, 1, 3]),
            "Ab": ([3, 4, 1, 2, 3, 1, 2, 3], [3, 2, 1, 4, 3, 2, 1, 3]),
        ]
        let minorTable: [String: (rh: [Int], lh: [Int])] = [
            "A": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "E": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "D": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "G": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
            "C": ([1, 2, 3, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 3, 2, 1]),
        ]
        let entry = type == .major ? table[tonic.ascii] : minorTable[tonic.ascii]
        guard let entry else { return nil }
        return hand == .right ? entry.rh : entry.lh
    }
}

/// A small, repeatable random number generator, so a generated exercise can be recreated from its seed.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    var state: UInt64
    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    public mutating func pick<T>(_ items: [T]) -> T { items[Int(next() % UInt64(items.count))] }
    public mutating func shuffled<T>(_ items: [T]) -> [T] {
        var a = items
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(i, Int(next() % UInt64(i + 1))) }
        return a
    }
}
