import Foundation

public enum Step: Int, Codable, CaseIterable, Sendable {
    case c = 0, d, e, f, g, a, b

    public var semitones: Int { [0, 2, 4, 5, 7, 9, 11][rawValue] }
    public var letter: String { ["C", "D", "E", "F", "G", "A", "B"][rawValue] }

    public init?(letter: Character) {
        guard let i = "CDEFGAB".firstIndex(of: Character(letter.uppercased())) else { return nil }
        self.init(rawValue: "CDEFGAB".distance(from: "CDEFGAB".startIndex, to: i))
    }

    /// The step `count` letters above this one, with how many octaves were crossed.
    public func advanced(by count: Int) -> (step: Step, octaves: Int) {
        let total = rawValue + count
        let wrapped = ((total % 7) + 7) % 7
        return (Step(rawValue: wrapped)!, Int((Double(total) / 7).rounded(.down)))
    }
}

/// A pitch with its written spelling. C4 is middle C (MIDI 60).
public struct SpelledPitch: Hashable, Codable, Sendable, CustomStringConvertible {
    public var step: Step
    public var alter: Int
    public var octave: Int

    public init(step: Step, alter: Int = 0, octave: Int) {
        self.step = step; self.alter = alter; self.octave = octave
    }

    public var midi: Int { (octave + 1) * 12 + step.semitones + alter }
    public var pitchClass: Int { ((step.semitones + alter) % 12 + 12) % 12 }

    public static func accidentalText(_ alter: Int) -> String {
        switch alter {
        case 0: return ""
        case 1: return "♯"
        case -1: return "♭"
        case 2: return "𝄪"
        case -2: return "♭♭"
        default: return alter > 0 ? String(repeating: "♯", count: alter) : String(repeating: "♭", count: -alter)
        }
    }

    /// Name without octave, such as "F♯".
    public var name: String { step.letter + SpelledPitch.accidentalText(alter) }
    public var description: String { "\(name)\(octave)" }

    /// Parses "C4", "F#5", "Bb3", "Ebb2".
    public init?(_ text: String) {
        var chars = Array(text)
        guard let first = chars.first, let step = Step(letter: first) else { return nil }
        chars.removeFirst()
        var alter = 0
        while let c = chars.first, c == "#" || c == "b" || c == "♯" || c == "♭" {
            alter += (c == "#" || c == "♯") ? 1 : -1
            chars.removeFirst()
        }
        guard let octave = Int(String(chars)) else { return nil }
        self.init(step: step, alter: alter, octave: octave)
    }

    /// A default spelling for a MIDI note, using sharps or flats.
    public static func from(midi: Int, preferFlats: Bool = false) -> SpelledPitch {
        let pc = ((midi % 12) + 12) % 12
        let octave = midi / 12 - 1
        let sharp: [(Step, Int)] = [(.c, 0), (.c, 1), (.d, 0), (.d, 1), (.e, 0), (.f, 0), (.f, 1), (.g, 0), (.g, 1), (.a, 0), (.a, 1), (.b, 0)]
        let flat: [(Step, Int)] = [(.c, 0), (.d, -1), (.d, 0), (.e, -1), (.e, 0), (.f, 0), (.g, -1), (.g, 0), (.a, -1), (.a, 0), (.b, -1), (.b, 0)]
        let (s, a) = (preferFlats ? flat : sharp)[pc]
        return SpelledPitch(step: s, alter: a, octave: octave)
    }
}

public enum MIDINote {
    /// Name such as "C♯4" for display.
    public static func name(_ midi: Int, preferFlats: Bool = false) -> String {
        SpelledPitch.from(midi: midi, preferFlats: preferFlats).description
    }
}
