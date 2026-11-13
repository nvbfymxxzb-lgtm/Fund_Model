import Foundation

public enum Hand: String, Codable, Sendable { case right, left }
public enum HandSelection: String, Codable, Sendable, CaseIterable { case right, left, both }
public enum TieRole: String, Codable, Sendable { case start, `continue`, stop }

public struct TimeSignature: Codable, Hashable, Sendable {
    public var beats: Int
    public var beatType: Int
    public init(beats: Int, beatType: Int) { self.beats = beats; self.beatType = beatType }
    public var length: Rational { Rational(beats, beatType) }
    /// Length of one counted beat. Compound meters (6/8, 9/8, 12/8) count dotted quarters.
    public var beatLength: Rational {
        if beatType == 8 && beats % 3 == 0 && beats > 3 { return Rational(3, 8) }
        return Rational(1, beatType)
    }
}

public struct ScoreWarning: Codable, Hashable, Sendable {
    public var code: String
    public var message: String
    public var measureIndex: Int?
    public init(code: String, message: String, measureIndex: Int? = nil) {
        self.code = code; self.message = message; self.measureIndex = measureIndex
    }
}

public struct ScoreNote: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var measureIndex: Int
    public var staff: Int            // 1 = upper, 2 = lower
    public var voice: Int
    public var pitch: SpelledPitch
    public var midi: Int
    public var onset: Rational       // within the measure, in whole notes
    public var duration: Rational
    public var tie: TieRole?
    public var isGrace: Bool
    public var hand: Hand
    public var finger: Int?

    public init(id: String, measureIndex: Int, staff: Int, voice: Int, pitch: SpelledPitch, onset: Rational,
                duration: Rational, tie: TieRole? = nil, isGrace: Bool = false, hand: Hand, finger: Int? = nil) {
        self.id = id; self.measureIndex = measureIndex; self.staff = staff; self.voice = voice
        self.pitch = pitch; self.midi = pitch.midi; self.onset = onset; self.duration = duration
        self.tie = tie; self.isGrace = isGrace; self.hand = hand; self.finger = finger
    }

    /// True when the learner must strike this note (not a tie continuation, not a grace note).
    public var isAttack: Bool { !isGrace && tie != .continue && tie != .stop }

    /// Key used to find the drawn note in the notation view: measure, MIDI pitch, onset.
    public var matchKey: String { "\(measureIndex):\(midi):\(onset.n)/\(onset.d)" }
}

public struct Measure: Codable, Hashable, Sendable {
    public var index: Int
    public var number: String
    public var length: Rational
    public var time: TimeSignature
    public var keyFifths: Int
    public var minor: Bool
    public var tempoBPM: Int?        // quarter notes per minute, when it changes here
    public var repeatStart: Bool
    public var repeatEnd: Bool
    public var endings: [Int]        // volta numbers this measure belongs to
    public var isPickup: Bool

    public init(index: Int, number: String, length: Rational, time: TimeSignature, keyFifths: Int = 0, minor: Bool = false,
                tempoBPM: Int? = nil, repeatStart: Bool = false, repeatEnd: Bool = false, endings: [Int] = [], isPickup: Bool = false) {
        self.index = index; self.number = number; self.length = length; self.time = time
        self.keyFifths = keyFifths; self.minor = minor; self.tempoBPM = tempoBPM
        self.repeatStart = repeatStart; self.repeatEnd = repeatEnd; self.endings = endings; self.isPickup = isPickup
    }
}

/// One pass through a measure during playback (repeats create several).
public struct Occurrence: Codable, Hashable, Sendable {
    public var index: Int
    public var measureIndex: Int
    public var pass: Int
}

public struct Score: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int = Score.currentSchemaVersion
    public var title: String
    public var composer: String
    public var measures: [Measure]
    public var notes: [ScoreNote]
    public var warnings: [ScoreWarning]
    /// Measures that hold notation the app does not grade (ornaments, grace notes, unsupported marks).
    public var unscoredMeasures: Set<Int>

    public init(title: String, composer: String = "", measures: [Measure], notes: [ScoreNote],
                warnings: [ScoreWarning] = [], unscoredMeasures: Set<Int> = []) {
        self.title = title; self.composer = composer; self.measures = measures; self.notes = notes
        self.warnings = warnings; self.unscoredMeasures = unscoredMeasures
    }

    public static let defaultTempoBPM = 80

    /// Tempo in force at a measure (the latest change at or before it).
    public func tempo(atMeasure index: Int) -> Int {
        var bpm = Score.defaultTempoBPM
        for m in measures where m.index <= index { if let t = m.tempoBPM { bpm = t } }
        return bpm
    }

    public var baseTempo: Int { tempo(atMeasure: 0) }

    public func notes(inMeasure index: Int) -> [ScoreNote] { notes.filter { $0.measureIndex == index } }

    /// Measures in the order they are played, with repeats and first/second endings expanded.
    public func playbackOrder() -> [Occurrence] {
        var result: [Occurrence] = []
        var i = 0
        var repeatStartIndex = 0
        var pass = 1
        var guardCount = 0
        while i < measures.count && guardCount < measures.count * 4 + 16 {
            guardCount += 1
            let m = measures[i]
            if m.repeatStart && repeatStartIndex != i { repeatStartIndex = i; pass = 1 }
            if !m.endings.isEmpty && !m.endings.contains(pass) { i += 1; continue }
            result.append(Occurrence(index: result.count, measureIndex: i, pass: pass))
            if m.repeatEnd {
                if pass == 1 { pass = 2; i = repeatStartIndex; continue }
                pass = 1; repeatStartIndex = i + 1
            }
            i += 1
        }
        return result
    }
}

/// A stretch of the playback order chosen for practice.
public struct Passage: Codable, Hashable, Sendable {
    public var firstOccurrence: Int
    public var lastOccurrence: Int
    public init(firstOccurrence: Int, lastOccurrence: Int) {
        self.firstOccurrence = firstOccurrence; self.lastOccurrence = lastOccurrence
    }
}

/// A note the learner is expected to strike, placed in time.
public struct ExpectedAttack: Codable, Hashable, Sendable, Identifiable {
    public var id: String              // "noteId@occurrence"
    public var noteId: String
    public var matchKey: String
    public var midi: Int
    public var hand: Hand
    public var occurrenceIndex: Int
    public var measureIndex: Int
    public var position: Rational      // whole notes from the passage start
    public var timeUs: Int64           // microseconds from the passage start at the chosen tempo
    public var durationUs: Int64       // sounding length including ties
    public var unscored: Bool
    public var finger: Int?
}

/// The notes of a passage placed in time at a chosen tempo.
public struct PassageTimeline: Sendable {
    /// The measure being played at a time, or nil before the start.
    public func measureIndex(atUs time: Int64) -> Int? {
        guard let i = measureStartsUs.lastIndex(where: { $0 <= time }) else { return measureIndexes.first }
        return measureIndexes[i]
    }

    public let passage: Passage
    public let tempoPercent: Int
    public let attacks: [ExpectedAttack]       // every hand, sorted by time
    public let totalUs: Int64
    public let measureStartsUs: [Int64]        // one per occurrence in the passage
    public let measureIndexes: [Int]           // the measure played at each of those occurrences
    public let beatTimesUs: [Int64]            // metronome clicks
    public let downbeatTimesUs: Set<Int64>

    public func attacks(for hand: HandSelection) -> [ExpectedAttack] {
        switch hand {
        case .both: return attacks
        case .right: return attacks.filter { $0.hand == .right }
        case .left: return attacks.filter { $0.hand == .left }
        }
    }

    /// Attacks of the hand that is not being practised.
    public func otherHandAttacks(for hand: HandSelection) -> [ExpectedAttack] {
        switch hand {
        case .both: return []
        case .right: return attacks.filter { $0.hand == .left }
        case .left: return attacks.filter { $0.hand == .right }
        }
    }
}

extension Score {
    public var wholePassage: Passage {
        Passage(firstOccurrence: 0, lastOccurrence: max(0, playbackOrder().count - 1))
    }

    /// The passage covering measures `first...last` (measure indexes), first time through.
    public func passage(measures first: Int, _ last: Int) -> Passage {
        let order = playbackOrder()
        let a = order.first { $0.measureIndex >= first }?.index ?? 0
        let fallback = order.last { $0.measureIndex <= last }?.index ?? a
        let firstHit = order.first { $0.index >= a && $0.measureIndex == last }?.index ?? fallback
        return Passage(firstOccurrence: a, lastOccurrence: max(a, firstHit))
    }

    /// Microseconds per whole note at a measure, scaled by the practice tempo percentage.
    func microsPerWhole(measure: Int, tempoPercent: Int) -> Rational {
        Rational(Int64(240_000_000) * 100, Int64(tempo(atMeasure: measure)) * Int64(max(tempoPercent, 1)))
    }

    public func timeline(passage: Passage, tempoPercent: Int = 100) -> PassageTimeline {
        let order = playbackOrder()
        guard !order.isEmpty else {
            return PassageTimeline(passage: passage, tempoPercent: tempoPercent, attacks: [], totalUs: 0,
                                   measureStartsUs: [], measureIndexes: [], beatTimesUs: [], downbeatTimesUs: [])
        }
        let lo = min(max(passage.firstOccurrence, 0), order.count - 1)
        let hi = min(max(passage.lastOccurrence, lo), order.count - 1)
        let byMeasure = Dictionary(grouping: notes, by: { $0.measureIndex })

        struct Placed { var note: ScoreNote; var occ: Occurrence; var position: Rational; var timeUs: Int64; var endUs: Int64 }
        var placed: [Placed] = []
        var measureStarts: [Int64] = []
        var beats: [Int64] = []
        var downbeats: Set<Int64> = []
        var positionCursor = Rational.zero
        var timeCursor = Rational.zero

        for occ in order[lo...hi] {
            let m = measures[occ.measureIndex]
            let perWhole = microsPerWhole(measure: m.index, tempoPercent: tempoPercent)
            let startUs = timeCursor.rounded
            measureStarts.append(startUs)
            // Metronome clicks. A pickup measure counts back from its end.
            let beat = m.time.beatLength
            var offset = m.isPickup ? (m.length - beat * Rational(Int64((m.length / beat).doubleValue.rounded(.down)))) : Rational.zero
            var first = !m.isPickup
            while offset < m.length {
                let t = (timeCursor + offset * perWhole).rounded
                beats.append(t)
                if first { downbeats.insert(t) }
                first = false
                offset += beat
            }
            for note in byMeasure[m.index] ?? [] where !note.isGrace {
                let t = (timeCursor + note.onset * perWhole).rounded
                let e = (timeCursor + (note.onset + note.duration) * perWhole).rounded
                placed.append(Placed(note: note, occ: occ, position: positionCursor + note.onset, timeUs: t, endUs: e))
            }
            positionCursor += m.length
            timeCursor += m.length * perWhole
        }

        placed.sort { ($0.timeUs, $0.note.midi, $0.note.id) < ($1.timeUs, $1.note.midi, $1.note.id) }
        // Follow tie chains so a tied note sounds for its full length.
        var attacks: [ExpectedAttack] = []
        for p in placed where p.note.isAttack {
            var endUs = p.endUs
            if p.note.tie == .start {
                var searching = true
                while searching {
                    searching = false
                    if let next = placed.first(where: { $0.note.midi == p.note.midi && !$0.note.isAttack && abs($0.timeUs - endUs) <= 1 && $0.timeUs > p.timeUs && $0.endUs > endUs }) {
                        endUs = next.endUs
                        searching = next.note.tie == .continue
                    }
                }
            }
            attacks.append(ExpectedAttack(
                id: "\(p.note.id)@\(p.occ.index)", noteId: p.note.id, matchKey: p.note.matchKey, midi: p.note.midi,
                hand: p.note.hand, occurrenceIndex: p.occ.index, measureIndex: p.occ.measureIndex,
                position: p.position, timeUs: p.timeUs, durationUs: max(endUs - p.timeUs, 1),
                unscored: unscoredMeasures.contains(p.occ.measureIndex), finger: p.note.finger))
        }
        return PassageTimeline(passage: Passage(firstOccurrence: lo, lastOccurrence: hi), tempoPercent: tempoPercent,
                               attacks: attacks, totalUs: timeCursor.rounded, measureStartsUs: measureStarts,
                               measureIndexes: order[lo...hi].map { $0.measureIndex },
                               beatTimesUs: beats, downbeatTimesUs: downbeats)
    }
}
