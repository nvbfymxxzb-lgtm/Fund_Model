import Foundation

/// A song written in the app's compact text notation.
///
/// Each hand is a string of tokens separated by spaces, with `|` between measures:
/// - note: `C4:q` (pitch, then a duration code). The duration carries over to following notes until changed.
/// - chord: `[C4 E4 G4]:h`
/// - rest: `r:q`
/// - durations: `w` whole, `h` half, `q` quarter, `e` eighth, `s` sixteenth; add `.` for dotted, `t` for triplet
/// - tie to the next note of the same pitch: `C4:h~`
/// - fingering: `C4:q/1`
/// - repeats: `|:` and `:|` (read from the right hand)
/// - an empty measure in a second voice: `-`
public struct SongSource: Codable, Hashable, Sendable {
    public var title: String
    public var composer: String
    public var keyFifths: Int
    public var minor: Bool
    public var time: String
    public var tempo: Int
    public var pickup: Bool
    public var rh: String
    public var lh: String
    public var rh2: String?
    public var lh2: String?

    public init(title: String, composer: String = "", keyFifths: Int = 0, minor: Bool = false, time: String = "4/4",
                tempo: Int = 80, pickup: Bool = false, rh: String, lh: String, rh2: String? = nil, lh2: String? = nil) {
        self.title = title; self.composer = composer; self.keyFifths = keyFifths; self.minor = minor
        self.time = time; self.tempo = tempo; self.pickup = pickup; self.rh = rh; self.lh = lh; self.rh2 = rh2; self.lh2 = lh2
    }
}

public struct TinyNotationError: Error, CustomStringConvertible, Equatable {
    public var message: String
    public var description: String { message }
}

public enum TinyNotation {
    struct Event { var pitches: [(SpelledPitch, Int?)]; var duration: Rational; var tied: Bool }
    struct ParsedMeasure { var events: [Event] = []; var repeatStart = false; var repeatEnd = false; var explicitEmpty = false }

    public static func duration(code: String) -> Rational? {
        var chars = Array(code)
        guard let first = chars.first else { return nil }
        chars.removeFirst()
        var value: Rational
        switch first {
        case "w": value = Rational(1, 1)
        case "h": value = Rational(1, 2)
        case "q": value = Rational(1, 4)
        case "e": value = Rational(1, 8)
        case "s": value = Rational(1, 16)
        default: return nil
        }
        for c in chars {
            switch c {
            case ".": value = value * Rational(3, 2)
            case "t": value = value * Rational(2, 3)
            default: return nil
            }
        }
        return value
    }

    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inChord = false
        for c in text {
            if c == "[" { inChord = true }
            if c == "]" { inChord = false }
            if c.isWhitespace && !inChord {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(c)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    static func parseVoice(_ text: String, name: String) throws -> [ParsedMeasure] {
        var measures: [ParsedMeasure] = [ParsedMeasure()]
        var sticky = Rational(1, 4)
        var sawAnything = false
        for token in tokenize(text) {
            if token == "|" || token == ":|" || token == "|:" || token == ":|:" {
                if token.hasPrefix(":") { measures[measures.count - 1].repeatEnd = true }
                let currentIsEmpty = measures[measures.count - 1].events.isEmpty && !measures[measures.count - 1].explicitEmpty
                if !(currentIsEmpty && !sawAnything) { measures.append(ParsedMeasure()) }
                if token.hasSuffix(":") && token != ":|" { measures[measures.count - 1].repeatStart = true }
                sawAnything = true
                continue
            }
            sawAnything = true
            if token == "-" { measures[measures.count - 1].explicitEmpty = true; continue }
            var body = token
            var finger: Int? = nil
            if let slash = body.lastIndex(of: "/"), let f = Int(body[body.index(after: slash)...]) {
                finger = f; body = String(body[..<slash])
            }
            var tied = false
            if body.hasSuffix("~") { tied = true; body.removeLast() }
            var pitchPart = body
            if let colon = body.lastIndex(of: ":") {
                let code = String(body[body.index(after: colon)...])
                guard let d = duration(code: code) else { throw TinyNotationError(message: "\(name): bad duration '\(code)' in '\(token)'") }
                sticky = d
                pitchPart = String(body[..<colon])
            }
            var pitches: [(SpelledPitch, Int?)] = []
            if pitchPart == "r" {
                // rest
            } else if pitchPart.hasPrefix("[") && pitchPart.hasSuffix("]") {
                for name in pitchPart.dropFirst().dropLast().split(separator: " ") {
                    guard let p = SpelledPitch(String(name)) else { throw TinyNotationError(message: "bad pitch '\(name)' in '\(token)'") }
                    pitches.append((p, nil))
                }
            } else {
                guard let p = SpelledPitch(pitchPart) else { throw TinyNotationError(message: "\(name): bad token '\(token)'") }
                pitches.append((p, finger))
            }
            measures[measures.count - 1].events.append(Event(pitches: pitches, duration: sticky, tied: tied))
        }
        if let last = measures.last, last.events.isEmpty, !last.explicitEmpty, measures.count > 1 { measures.removeLast() }
        return measures
    }

    public static func parse(_ source: SongSource) throws -> Score {
        let parts = source.time.split(separator: "/").compactMap { Int($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { throw TinyNotationError(message: "bad time signature '\(source.time)'") }
        let time = TimeSignature(beats: parts[0], beatType: parts[1])

        var voices: [(staff: Int, voice: Int, name: String, measures: [ParsedMeasure])] = []
        voices.append((1, 1, "rh", try parseVoice(source.rh, name: "rh")))
        if let t = source.rh2, !t.isEmpty { voices.append((1, 2, "rh2", try parseVoice(t, name: "rh2"))) }
        voices.append((2, 1, "lh", try parseVoice(source.lh, name: "lh")))
        if let t = source.lh2, !t.isEmpty { voices.append((2, 2, "lh2", try parseVoice(t, name: "lh2"))) }

        let count = voices[0].measures.count
        for v in voices where v.measures.count != count {
            throw TinyNotationError(message: "\(source.title): \(v.name) has \(v.measures.count) measures but rh has \(count)")
        }

        var measures: [Measure] = []
        var notes: [ScoreNote] = []
        var pendingTies: [String: Set<Int>] = [:]

        for mi in 0..<count {
            var lengths: [Rational] = []
            for v in voices {
                let pm = v.measures[mi]
                if pm.events.isEmpty { continue }
                lengths.append(pm.events.reduce(Rational.zero) { $0 + $1.duration })
            }
            guard let length = lengths.first else { throw TinyNotationError(message: "\(source.title): measure \(mi + 1) is empty") }
            for (i, l) in lengths.enumerated() where l != length {
                throw TinyNotationError(message: "\(source.title): measure \(mi + 1): voices disagree on length (\(length) vs \(l), voice \(i))")
            }
            let isPickup = source.pickup && mi == 0
            let isShortLast = source.pickup && mi == count - 1
            if length != time.length {
                if !(isPickup && length < time.length) && !(isShortLast && length < time.length) {
                    throw TinyNotationError(message: "\(source.title): measure \(mi + 1) lasts \(length) but the time signature needs \(time.length)")
                }
            }
            let number = source.pickup ? "\(mi)" : "\(mi + 1)"
            measures.append(Measure(index: mi, number: number, length: length, time: time, keyFifths: source.keyFifths,
                                    minor: source.minor, tempoBPM: mi == 0 ? source.tempo : nil,
                                    repeatStart: voices[0].measures[mi].repeatStart, repeatEnd: voices[0].measures[mi].repeatEnd,
                                    endings: [], isPickup: isPickup))
            for v in voices {
                var onset = Rational.zero
                let key = "\(v.staff).\(v.voice)"
                for (ei, e) in v.measures[mi].events.enumerated() {
                    var nextPending: Set<Int> = []
                    for (pi, (pitch, finger)) in e.pitches.enumerated() {
                        let incoming = pendingTies[key]?.contains(pitch.midi) ?? false
                        var role: TieRole? = nil
                        if incoming && e.tied { role = .continue } else if incoming { role = .stop } else if e.tied { role = .start }
                        if e.tied { nextPending.insert(pitch.midi) }
                        notes.append(ScoreNote(id: "m\(mi).s\(v.staff).v\(v.voice).e\(ei).p\(pi)", measureIndex: mi, staff: v.staff,
                                               voice: v.voice, pitch: pitch, onset: onset, duration: e.duration, tie: role,
                                               hand: v.staff == 1 ? .right : .left, finger: finger))
                    }
                    if !e.pitches.isEmpty || e.tied { pendingTies[key] = nextPending }
                    onset += e.duration
                }
            }
        }
        return Score(title: source.title, composer: source.composer, measures: measures, notes: notes)
    }
}
