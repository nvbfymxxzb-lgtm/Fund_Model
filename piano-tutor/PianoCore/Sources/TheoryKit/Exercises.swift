import Foundation
import MusicModel
import PracticeEngine

public enum ExerciseKind: String, Codable, Sendable {
    case playChord          // play a named chord on the piano
    case playProgression    // play a series of chords
    case playScale          // play a scale; graded by the practice engine
    case playInterval       // play the note a given interval above a starting note
    case earInterval        // hear two notes, name the interval
    case earChord           // hear a chord, name its type
    case choice             // answer a question by tapping
}

/// One question in a lesson.
public struct Exercise: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: ExerciseKind
    public var prompt: String
    public var chord: ChordSpec?
    public var requireInversion: Bool?
    public var chords: [ChordSpec]?
    public var labels: [String]?
    public var scaleTonic: String?
    public var scaleType: ScaleType?
    public var hand: HandSelection?
    public var octaves: Int?
    public var rootMidi: Int?
    public var semitones: Int?
    public var options: [String]?
    public var answer: Int?
    public var explanation: String?
    public var skillIds: [String]?

    public init(id: String, kind: ExerciseKind, prompt: String, chord: ChordSpec? = nil, requireInversion: Bool? = nil,
                chords: [ChordSpec]? = nil, labels: [String]? = nil, scaleTonic: String? = nil, scaleType: ScaleType? = nil,
                hand: HandSelection? = nil, octaves: Int? = nil, rootMidi: Int? = nil, semitones: Int? = nil,
                options: [String]? = nil, answer: Int? = nil, explanation: String? = nil, skillIds: [String]? = nil) {
        self.id = id; self.kind = kind; self.prompt = prompt; self.chord = chord; self.requireInversion = requireInversion
        self.chords = chords; self.labels = labels; self.scaleTonic = scaleTonic; self.scaleType = scaleType; self.hand = hand
        self.octaves = octaves; self.rootMidi = rootMidi; self.semitones = semitones; self.options = options
        self.answer = answer; self.explanation = explanation; self.skillIds = skillIds
    }

    /// True when the exercise is answered on the piano keys.
    public var usesPiano: Bool { [.playChord, .playProgression, .playScale, .playInterval].contains(kind) }
}

public enum ChordAnswer: Equatable, Sendable {
    case correct
    case incomplete(missing: [String])
    case wrongNotes(extra: [Int])
    case wrongInversion(expectedBass: String)
    case nothing
}

public enum ExerciseChecker {
    /// Checks the keys currently held against a chord. Any octave and any doubling is accepted.
    public static func chord(held: Set<Int>, spec: ChordSpec, requireInversion: Bool) -> ChordAnswer {
        guard !held.isEmpty else { return .nothing }
        let target = spec.pitchClasses
        let heldClasses = Set(held.map { $0 % 12 })
        let extra = held.filter { !target.contains($0 % 12) }.sorted()
        if !extra.isEmpty { return .wrongNotes(extra: extra) }
        let missing = spec.tones.filter { !heldClasses.contains($0.pitchClass) }
        if !missing.isEmpty { return .incomplete(missing: missing.map { $0.description }) }
        if requireInversion, let lowest = held.min(), lowest % 12 != spec.bass.pitchClass {
            return .wrongInversion(expectedBass: spec.bass.description)
        }
        return .correct
    }

    /// Checks an interval answer: the target note must be held, alone or with the starting note.
    public static func interval(held: Set<Int>, rootMidi: Int, semitones: Int) -> ChordAnswer {
        guard !held.isEmpty else { return .nothing }
        let target = rootMidi + semitones
        let extra = held.filter { $0 != target && $0 != rootMidi }.sorted()
        if !extra.isEmpty { return .wrongNotes(extra: extra) }
        return held.contains(target) ? .correct : .incomplete(missing: [MIDINote.name(target)])
    }

    public static func choice(_ exercise: Exercise, picked: Int) -> Bool { exercise.answer == picked }
}

public enum TheoryScores {
    /// A scale written out as a short score, with standard fingering where the app has one.
    public static func scale(tonic: NoteName, type: ScaleType, hand: HandSelection = .right, octaves: Int = 1, tempo: Int = 72) -> Score {
        func line(_ h: Hand) -> String {
            let up = Theory.scalePitches(tonic, type, from: h == .right ? 60 : 48, octaves: octaves)
            // Melodic minor descends as natural minor.
            let downSource = type == .melodicMinor ? Theory.scalePitches(tonic, .naturalMinor, from: h == .right ? 60 : 48, octaves: octaves) : up
            let down = Array(downSource.reversed().dropFirst())
            var fingersUp: [Int?] = Array(repeating: nil, count: up.count)
            if let f = Theory.scaleFingering(tonic: tonic, type: type == .major ? .major : .naturalMinor, hand: h), octaves == 1 {
                fingersUp = f.map { Optional($0) }
            }
            let fingersDown = Array(fingersUp.reversed().dropFirst())
            var tokens: [String] = []
            let all = Array(zip(up, fingersUp)) + Array(zip(down, fingersDown))
            for (i, (p, f)) in all.enumerated() {
                let name = p.step.letter + (p.alter > 0 ? String(repeating: "#", count: p.alter) : String(repeating: "b", count: -p.alter)) + "\(p.octave)"
                let isLast = i == all.count - 1
                tokens.append(name + (isLast ? ":h" : ":q") + (f.map { "/\($0)" } ?? ""))
                if isLast && (all.count + 1) % 4 != 0 { tokens.append("r:h") }
                if (i + 1) % 4 == 0 && !isLast { tokens.append("|") }
            }
            return tokens.joined(separator: " ")
        }
        let measures = (octaves * 14 + 2 + 3) / 4
        let rest = Array(repeating: "r:w", count: measures).joined(separator: " | ")
        let fifths = type == .major ? Theory.fifths(majorTonic: tonic) : Theory.fifths(minorTonic: tonic)
        let source = SongSource(title: "\(tonic) \(type.title) scale", keyFifths: max(-7, min(7, fifths)), minor: type != .major, time: "4/4", tempo: tempo,
                                rh: hand == .left ? rest : line(.right), lh: hand == .right ? rest : line(.left))
        // The generator above always fills whole measures, so a failure here is a programming error.
        return (try? TinyNotation.parse(source)) ?? Score(title: source.title, measures: [], notes: [])
    }

    /// Chords written as whole notes, one per measure, for showing a progression.
    public static func chords(_ specs: [ChordSpec], keyFifths: Int = 0, minor: Bool = false, title: String = "Chords") -> Score {
        var rh: [String] = [], lh: [String] = []
        for spec in specs {
            let notes = spec.pitches(above: 60).map { $0.step.letter + ($0.alter > 0 ? String(repeating: "#", count: $0.alter) : String(repeating: "b", count: -$0.alter)) + "\($0.octave)" }
            rh.append("[\(notes.joined(separator: " "))]:w")
            let b = spec.bass
            var bass = SpelledPitch(step: b.step, alter: b.alter, octave: 2)
            if bass.midi < 41 { bass.octave = 3 }
            lh.append(b.step.letter + (b.alter > 0 ? String(repeating: "#", count: b.alter) : String(repeating: "b", count: -b.alter)) + "\(bass.octave):w")
        }
        let source = SongSource(title: title, keyFifths: keyFifths, minor: minor, time: "4/4", tempo: 60, rh: rh.joined(separator: " | "), lh: lh.joined(separator: " | "))
        return (try? TinyNotation.parse(source)) ?? Score(title: title, measures: [], notes: [])
    }
}

/// Describes a set of questions to create. The same seed always creates the same questions.
public struct GeneratorSpec: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case chordPlay, chordSpell, keySignature, intervalName, intervalPlay, earInterval, earChord, romanPlay, romanName, scaleNotes
    }
    public var kind: Kind
    public var count: Int
    /// Major-key tonics such as "C", "G", "Bb". Minor keys are written "Am".
    public var keys: [String]?
    public var qualities: [ChordQuality]?
    public var inversions: Bool?
    public var semitones: [Int]?
    public var degrees: [Int]?

    public init(kind: Kind, count: Int, keys: [String]? = nil, qualities: [ChordQuality]? = nil, inversions: Bool? = nil,
                semitones: [Int]? = nil, degrees: [Int]? = nil) {
        self.kind = kind; self.count = count; self.keys = keys; self.qualities = qualities
        self.inversions = inversions; self.semitones = semitones; self.degrees = degrees
    }
}

public enum ExerciseGenerator {
    static func parseKey(_ text: String) -> (tonic: NoteName, minor: Bool) {
        if text.hasSuffix("m"), let n = NoteName(String(text.dropLast())) { return (n, true) }
        return (NoteName(text) ?? NoteName(.c), false)
    }

    static func options(correct: String, distractors: [String], rng: inout SeededGenerator) -> (options: [String], answer: Int) {
        var unique: [String] = []
        for d in distractors where d != correct && !unique.contains(d) { unique.append(d) }
        let picked = Array(rng.shuffled(unique).prefix(3))
        let all = rng.shuffled(picked + [correct])
        return (all, all.firstIndex(of: correct) ?? 0)
    }

    public static func make(_ spec: GeneratorSpec, seed: UInt64, idPrefix: String = "gen") -> [Exercise] {
        var rng = SeededGenerator(seed: seed)
        let keys = spec.keys ?? ["C", "G", "F", "D", "Bb"]
        let qualities = spec.qualities ?? [.major, .minor]
        let roots = ["C", "D", "E", "F", "G", "A", "B", "Bb", "Eb", "F#", "Ab"]
        var result: [Exercise] = []
        var lastSignature = ""
        var attempts = 0
        while result.count < spec.count && attempts < spec.count * 20 {
            attempts += 1
            let id = "\(idPrefix).\(result.count)"
            var e: Exercise
            switch spec.kind {
            case .chordPlay:
                let chordRoots = spec.keys ?? roots
                var chord = ChordSpec(root: rng.pick(chordRoots), quality: rng.pick(qualities))
                if spec.inversions == true { chord.inversion = Int(rng.next() % UInt64(chord.tones.count)) }
                let needInversion = spec.inversions == true
                e = Exercise(id: id, kind: .playChord,
                             prompt: needInversion ? "Play \(chord.title), \(chord.inversionName) (\(chord.bass) at the bottom)." : "Play a \(chord.title) chord.",
                             chord: chord, requireInversion: needInversion,
                             explanation: "\(chord.title) is \(chord.tones.map { $0.description }.joined(separator: " – ")).")
            case .chordSpell:
                let chord = ChordSpec(root: rng.pick(spec.keys ?? roots), quality: rng.pick(qualities))
                let correct = chord.tones.map { $0.description }.joined(separator: " – ")
                var wrong: [String] = []
                for q in ChordQuality.allCases where q.isSeventh == chord.quality.isSeventh && q != chord.quality {
                    wrong.append(ChordSpec(root: chord.root, quality: q).tones.map { $0.description }.joined(separator: " – "))
                }
                let o = options(correct: correct, distractors: wrong, rng: &rng)
                e = Exercise(id: id, kind: .choice, prompt: "Which notes make a \(chord.title) chord?", options: o.options, answer: o.answer,
                             explanation: "\(chord.title) is \(correct).")
            case .keySignature:
                let k = parseKey(rng.pick(keys))
                let f = k.minor ? Theory.fifths(minorTonic: k.tonic) : Theory.fifths(majorTonic: k.tonic)
                func text(_ n: Int) -> String { n == 0 ? "no sharps or flats" : (n > 0 ? "\(n) sharp\(n == 1 ? "" : "s")" : "\(-n) flat\(n == -1 ? "" : "s")") }
                let o = options(correct: text(f), distractors: [f + 1, f - 1, -f, f + 2, f - 2].filter { abs($0) <= 6 }.map(text), rng: &rng)
                let sig = Theory.signature(fifths: f).map { $0.description }.joined(separator: ", ")
                e = Exercise(id: id, kind: .choice, prompt: "What is the key signature of \(k.tonic) \(k.minor ? "minor" : "major")?", options: o.options, answer: o.answer,
                             explanation: f == 0 ? "\(k.tonic) \(k.minor ? "minor" : "major") has no sharps or flats." : "\(k.tonic) \(k.minor ? "minor" : "major") has \(text(f)): \(sig).")
            case .intervalName, .earInterval, .intervalPlay:
                let semis = rng.pick(spec.semitones ?? [2, 3, 4, 5, 7, 12])
                let root = 55 + Int(rng.next() % 10)
                let name = Theory.intervalNamesBySemitones[min(max(semis, 0), 12)]
                if spec.kind == .intervalPlay {
                    e = Exercise(id: id, kind: .playInterval, prompt: "Play the note a \(name) above \(MIDINote.name(root)).", rootMidi: root, semitones: semis,
                                 explanation: "A \(name) is \(semis) half steps: \(MIDINote.name(root)) up to \(MIDINote.name(root + semis)).")
                } else {
                    let pool = (spec.semitones ?? [1, 2, 3, 4, 5, 7, 8, 9, 12]).map { Theory.intervalNamesBySemitones[min(max($0, 0), 12)] }
                    let o = options(correct: name, distractors: pool + ["major third", "perfect fifth", "major second", "octave"], rng: &rng)
                    e = Exercise(id: id, kind: spec.kind == .earInterval ? .earInterval : .choice,
                                 prompt: spec.kind == .earInterval ? "Listen. Which interval is it?" : "What is the interval from \(MIDINote.name(root)) up to \(MIDINote.name(root + semis))?",
                                 rootMidi: root, semitones: semis, options: o.options, answer: o.answer,
                                 explanation: "\(MIDINote.name(root)) up to \(MIDINote.name(root + semis)) is \(semis) half steps: a \(name).")
                }
            case .earChord:
                let chord = ChordSpec(root: rng.pick(roots), quality: rng.pick(qualities))
                let o = options(correct: chord.quality.title, distractors: qualities.map { $0.title } + ["major", "minor", "diminished"], rng: &rng)
                e = Exercise(id: id, kind: .earChord, prompt: "Listen. What kind of chord is it?", chord: chord, options: o.options, answer: o.answer,
                             explanation: "That was \(chord.title): \(chord.tones.map { $0.description }.joined(separator: " – ")).")
            case .romanPlay, .romanName:
                let k = parseKey(rng.pick(keys))
                let degree = rng.pick(spec.degrees ?? [1, 4, 5, 6])
                let chord = Theory.diatonicTriad(degree: degree, tonic: k.tonic, minor: k.minor)
                let roman = Theory.roman(degree: degree, quality: chord.quality)
                let keyName = "\(k.tonic) \(k.minor ? "minor" : "major")"
                if spec.kind == .romanPlay {
                    e = Exercise(id: id, kind: .playChord, prompt: "Play the \(roman) chord in \(keyName).", chord: chord, requireInversion: false,
                                 explanation: "\(roman) in \(keyName) is \(chord.title): \(chord.tones.map { $0.description }.joined(separator: " – ")).")
                } else {
                    let others = [1, 2, 3, 4, 5, 6].map { Theory.diatonicTriad(degree: $0, tonic: k.tonic, minor: k.minor) }.map { $0.symbol }
                    let o = options(correct: chord.symbol, distractors: others, rng: &rng)
                    e = Exercise(id: id, kind: .choice, prompt: "Which chord is \(roman) in \(keyName)?", options: o.options, answer: o.answer,
                                 explanation: "\(roman) in \(keyName) is \(chord.symbol) (\(chord.tones.map { $0.description }.joined(separator: " – "))).")
                }
            case .scaleNotes:
                let k = parseKey(rng.pick(keys))
                let type: ScaleType = k.minor ? .naturalMinor : .major
                let notes = Theory.scale(k.tonic, type)
                let degree = 1 + Int(rng.next() % 6) + 1
                let correct = notes[degree - 1].description
                let ordinal = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th"][degree - 1]
                let o = options(correct: correct, distractors: notes.map { $0.description } + [notes[degree - 1].up(letters: 0, semitones: 1).description, notes[degree - 1].up(letters: 0, semitones: -1).description], rng: &rng)
                e = Exercise(id: id, kind: .choice, prompt: "What is the \(ordinal) note of the \(k.tonic) \(type.title) scale?", options: o.options, answer: o.answer,
                             explanation: "\(k.tonic) \(type.title): \(notes.prefix(7).map { $0.description }.joined(separator: " "))." )
            }
            // Avoid asking the same thing twice in a row.
            let signature = "\(e.prompt)|\(e.rootMidi ?? -1)|\(e.semitones ?? -1)|\(e.chord?.symbol ?? "")"
            if signature == lastSignature { continue }
            lastSignature = signature
            result.append(e)
        }
        return result
    }
}
