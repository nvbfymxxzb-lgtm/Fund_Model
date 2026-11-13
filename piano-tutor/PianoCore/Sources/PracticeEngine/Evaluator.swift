import Foundation
import MusicModel

/// Time windows used for grading. All values are starting points to tune on a real piano.
public struct Tolerances: Codable, Hashable, Sendable {
    public static let version = "tol-1"
    /// Longest gap between the first and last note of a chord in strict mode.
    public var chordSpreadUs: Int64 = 120_000
    /// A note further than this from its expected time does not count as that note.
    public var acceptUs: Int64 = 200_000
    /// A note within this distance counts as on time.
    public var onTimeUs: Int64 = 75_000
    public var strictChords = true
    /// Measured delay of the input, subtracted from every played note in rhythm mode.
    public var calibrationOffsetUs: Int64 = 0
    /// Wrong notes on one chord before the app shows a hint.
    public var hintAfterWrongNotes = 3

    public init() {}
}

public enum Classification: String, Codable, Sendable {
    case hit          // wait mode: right note
    case onTime, early, late
    case missed, extra, wrongPitch, excluded
}

public enum ExclusionReason: String, Codable, Sendable {
    case unsupportedSpan, inputDisconnected, otherHand
}

public struct Evaluation: Codable, Hashable, Sendable {
    public var expectedId: String?
    public var observedSeqs: [Int64]
    public var classification: Classification
    public var onsetErrorUs: Int64?
    public var expectedMidi: Int?
    public var playedMidi: Int?
    public var octaveError: Bool
    public var measureIndex: Int?
    public var matchKey: String?
    public var excludedReason: ExclusionReason?
    public var note: String?

    public init(expectedId: String? = nil, observedSeqs: [Int64] = [], classification: Classification, onsetErrorUs: Int64? = nil,
                expectedMidi: Int? = nil, playedMidi: Int? = nil, octaveError: Bool = false, measureIndex: Int? = nil,
                matchKey: String? = nil, excludedReason: ExclusionReason? = nil, note: String? = nil) {
        self.expectedId = expectedId; self.observedSeqs = observedSeqs; self.classification = classification
        self.onsetErrorUs = onsetErrorUs; self.expectedMidi = expectedMidi; self.playedMidi = playedMidi
        self.octaveError = octaveError; self.measureIndex = measureIndex; self.matchKey = matchKey
        self.excludedReason = excludedReason; self.note = note
    }
}

public enum AttemptResult: String, Codable, Sendable { case pass, fail, inconclusive }

/// The grade for one run through a passage.
public struct AttemptReport: Codable, Hashable, Sendable {
    public var mode: PracticeMode
    public var evaluations: [Evaluation]
    public var scoredCount: Int
    public var matchedCount: Int
    public var missedCount: Int
    public var extraCount: Int
    public var wrongCount: Int
    public var onTimeCount: Int
    public var excludedCount: Int
    public var assisted: Bool
    public var result: AttemptResult
    /// Measures with the most mistakes, worst first.
    public var troubleMeasures: [Int]
    public var meanOnsetErrorUs: Int64?

    public var accuracy: Double { scoredCount == 0 ? 0 : Double(matchedCount) / Double(scoredCount) }
    public var onTimeShare: Double { matchedCount == 0 ? 0 : Double(onTimeCount) / Double(matchedCount) }
}

public enum Evaluator {
    public static let version = "eval-1"

    /// Applies the pass rule to a set of evaluations.
    static func report(mode: PracticeMode, evaluations: [Evaluation], assisted: Bool) -> AttemptReport {
        let expected = evaluations.filter { $0.expectedId != nil }
        let excluded = expected.filter { $0.classification == .excluded }.count
        let scored = expected.count - excluded
        let matched = expected.filter { [.hit, .onTime, .early, .late].contains($0.classification) }.count
        let missed = expected.filter { $0.classification == .missed }.count
        let wrong = evaluations.filter { $0.classification == .wrongPitch }.count
        let extra = evaluations.filter { $0.classification == .extra }.count
        let onTime = expected.filter { $0.classification == .onTime || $0.classification == .hit }.count
        let errors = evaluations.compactMap { e -> Int64? in
            [.onTime, .early, .late].contains(e.classification) ? e.onsetErrorUs : nil
        }
        let mean = errors.isEmpty ? nil : errors.reduce(0, +) / Int64(errors.count)

        var result: AttemptResult
        if expected.isEmpty || Double(excluded) > 0.10 * Double(expected.count) {
            result = .inconclusive
        } else {
            let extraLimit = max(1, Int((0.05 * Double(scored)).rounded(.down)))
            // In wait mode wrong notes never advance the music, so they count against the extra-note allowance.
            let stray = mode == .wait ? extra + wrong : extra
            var ok = matched == scored && stray <= extraLimit
            if mode == .rhythm { ok = ok && wrong == 0 && Double(onTime) >= 0.8 * Double(max(matched, 1)) }
            result = ok ? .pass : .fail
        }

        var tally: [Int: Int] = [:]
        for e in evaluations where [.missed, .wrongPitch, .extra, .early, .late].contains(e.classification) {
            if let m = e.measureIndex { tally[m, default: 0] += (e.classification == .early || e.classification == .late) ? 1 : 2 }
        }
        let trouble = tally.sorted { ($0.value, -$0.key) > ($1.value, -$1.key) }.map { $0.key }

        return AttemptReport(mode: mode, evaluations: evaluations, scoredCount: scored, matchedCount: matched, missedCount: missed,
                             extraCount: extra, wrongCount: wrong, onTimeCount: onTime, excludedCount: excluded,
                             assisted: assisted, result: result, troubleMeasures: trouble, meanOnsetErrorUs: mean)
    }
}

/// Notes that begin at the same moment and must be played together.
public struct OnsetGroup: Hashable, Sendable {
    public var index: Int
    public var timeUs: Int64
    public var attacks: [ExpectedAttack]
    public var pitches: Set<Int> { Set(attacks.map { $0.midi }) }
    public var measureIndex: Int { attacks.first?.measureIndex ?? 0 }
}

public enum WaitFeedback: Equatable, Sendable {
    case ignored
    case correct(midi: Int, groupComplete: Bool)
    case wrong(midi: Int, octaveError: Bool)
    case otherHand(midi: Int)
    case chordTooSpread(midi: Int)
    case paused
    case finished
}

/// Wait mode: the music stands still until the right notes are played.
public struct WaitModeSession: Sendable {
    public let groups: [OnsetGroup]
    public let tolerances: Tolerances
    let otherHand: [ExpectedAttack]
    let skipped: [ExpectedAttack]

    public private(set) var index = 0
    public private(set) var satisfied: Set<Int> = []
    public private(set) var wrongOnCurrent = 0
    public private(set) var assisted = false
    public private(set) var paused = false
    public private(set) var evaluations: [Evaluation] = []
    var firstSatisfiedUs: Int64?
    var satisfiedSeqs: [Int: Int64] = [:]

    public init(timeline: PassageTimeline, hand: HandSelection, tolerances: Tolerances = Tolerances()) {
        self.tolerances = tolerances
        let mine = timeline.attacks(for: hand)
        skipped = mine.filter { $0.unscored }
        otherHand = timeline.otherHandAttacks(for: hand)
        var built: [OnsetGroup] = []
        for a in mine where !a.unscored {
            if let last = built.last, last.timeUs == a.timeUs { built[built.count - 1].attacks.append(a) }
            else { built.append(OnsetGroup(index: built.count, timeUs: a.timeUs, attacks: [a])) }
        }
        groups = built
        for a in skipped {
            evaluations.append(Evaluation(expectedId: a.id, classification: .excluded, expectedMidi: a.midi,
                                          measureIndex: a.measureIndex, matchKey: a.matchKey, excludedReason: .unsupportedSpan))
        }
    }

    public var isFinished: Bool { index >= groups.count }
    public var currentGroup: OnsetGroup? { isFinished ? nil : groups[index] }
    /// True once the learner has struggled enough on this chord that the note names should be shown.
    public var needsHint: Bool { wrongOnCurrent >= tolerances.hintAfterWrongNotes }
    public var remainingPitches: Set<Int> { (currentGroup?.pitches ?? []).subtracting(satisfied) }

    public mutating func resume() { paused = false }

    public mutating func handle(_ e: PerformanceEvent) -> WaitFeedback {
        if e.type == .disconnect { paused = true; satisfied = []; firstSatisfiedUs = nil; satisfiedSeqs = [:]; return .paused }
        if e.type == .reconnect { return .ignored }
        guard e.type == .noteOn, let midi = e.pitch else { return .ignored }
        guard !paused else { return .paused }
        guard let group = currentGroup else { return .finished }

        if group.pitches.contains(midi) && !satisfied.contains(midi) {
            if tolerances.strictChords, let first = firstSatisfiedUs, e.timeUs - first > tolerances.chordSpreadUs {
                // Too slow to count as one chord: start the chord again from this note.
                satisfied = [midi]; satisfiedSeqs = [midi: e.seq]; firstSatisfiedUs = e.timeUs
                return .chordTooSpread(midi: midi)
            }
            satisfied.insert(midi); satisfiedSeqs[midi] = e.seq
            if firstSatisfiedUs == nil { firstSatisfiedUs = e.timeUs }
            if satisfied == group.pitches {
                for a in group.attacks {
                    evaluations.append(Evaluation(expectedId: a.id, observedSeqs: [satisfiedSeqs[a.midi] ?? e.seq], classification: .hit,
                                                  expectedMidi: a.midi, playedMidi: a.midi, measureIndex: a.measureIndex, matchKey: a.matchKey))
                }
                index += 1; satisfied = []; satisfiedSeqs = [:]; firstSatisfiedUs = nil; wrongOnCurrent = 0
                return .correct(midi: midi, groupComplete: true)
            }
            return .correct(midi: midi, groupComplete: false)
        }

        // A note that belongs to the hand not being practised, near the current place, is not a mistake.
        let lower = index > 0 ? groups[index - 1].timeUs : Int64.min
        let upper = index + 1 < groups.count ? groups[index + 1].timeUs : Int64.max
        if otherHand.contains(where: { $0.midi == midi && $0.timeUs >= lower && $0.timeUs <= upper }) {
            evaluations.append(Evaluation(observedSeqs: [e.seq], classification: .excluded, playedMidi: midi,
                                          measureIndex: group.measureIndex, excludedReason: .otherHand))
            return .otherHand(midi: midi)
        }

        let octave = group.pitches.contains { abs($0 - midi) % 12 == 0 }
        wrongOnCurrent += 1
        if needsHint { assisted = true }
        let nearest = group.pitches.min { abs($0 - midi) < abs($1 - midi) }
        evaluations.append(Evaluation(observedSeqs: [e.seq], classification: .wrongPitch, expectedMidi: nearest, playedMidi: midi,
                                      octaveError: octave, measureIndex: group.measureIndex))
        return .wrong(midi: midi, octaveError: octave)
    }

    /// The grade so far. Notes not yet reached count as missed.
    public func report() -> AttemptReport {
        var all = evaluations
        if !isFinished {
            for g in groups[index...] {
                for a in g.attacks {
                    all.append(Evaluation(expectedId: a.id, classification: paused ? .excluded : .missed, expectedMidi: a.midi,
                                          measureIndex: a.measureIndex, matchKey: a.matchKey,
                                          excludedReason: paused ? .inputDisconnected : nil))
                }
            }
        }
        return Evaluator.report(mode: .wait, evaluations: all, assisted: assisted)
    }
}

/// Rhythm mode: the music keeps time and every note is checked against when it should have sounded.
public enum RhythmEvaluator {
    struct Observed { var seq: Int64; var midi: Int; var timeUs: Int64; var used = false }

    /// Order-preserving matching of expected and played times for one pitch.
    /// Finds the most matches, then the smallest total error, then prefers earlier played notes.
    static func match(expected: [Int64], observed: [Int64], window: Int64) -> [(Int, Int)] {
        let n = expected.count, m = observed.count
        guard n > 0, m > 0 else { return [] }
        var count = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        var cost = [[Int64]](repeating: [Int64](repeating: 0, count: m + 1), count: n + 1)
        func better(_ c1: Int, _ k1: Int64, _ c2: Int, _ k2: Int64) -> Bool { c1 > c2 || (c1 == c2 && k1 < k2) }
        for i in 1...n {
            for j in 1...m {
                var bc = count[i - 1][j], bk = cost[i - 1][j]
                if better(count[i][j - 1], cost[i][j - 1], bc, bk) { bc = count[i][j - 1]; bk = cost[i][j - 1] }
                let delta = abs(observed[j - 1] - expected[i - 1])
                if delta <= window {
                    let c = count[i - 1][j - 1] + 1, k = cost[i - 1][j - 1] + delta
                    if better(c, k, bc, bk) { bc = c; bk = k }
                }
                count[i][j] = bc; cost[i][j] = bk
            }
        }
        var pairs: [(Int, Int)] = []
        var i = n, j = m
        while i > 0 && j > 0 {
            if count[i][j] == count[i][j - 1] && cost[i][j] == cost[i][j - 1] { j -= 1; continue }
            if count[i][j] == count[i - 1][j] && cost[i][j] == cost[i - 1][j] { i -= 1; continue }
            pairs.append((i - 1, j - 1)); i -= 1; j -= 1
        }
        return pairs.reversed()
    }

    public static func evaluate(timeline: PassageTimeline, hand: HandSelection, events: [PerformanceEvent],
                                tolerances: Tolerances = Tolerances()) -> AttemptReport {
        let mine = timeline.attacks(for: hand)
        var evaluations: [Evaluation] = []

        // After a disconnect nothing is graded: a dropped connection must never add mistakes.
        var cutoff = Int64.max
        if let drop = events.first(where: { $0.type == .disconnect }) {
            cutoff = events.last(where: { $0.seq < drop.seq && $0.type != .disconnect })?.timeUs ?? drop.timeUs
            cutoff = min(cutoff, drop.timeUs) - tolerances.calibrationOffsetUs
        }

        var observed: [Observed] = events.filter { $0.type == .noteOn && $0.pitch != nil }
            .map { Observed(seq: $0.seq, midi: $0.pitch!, timeUs: $0.timeUs - tolerances.calibrationOffsetUs) }
            .filter { $0.timeUs <= cutoff }
            .sorted { ($0.timeUs, $0.seq) < ($1.timeUs, $1.seq) }

        var open: [ExpectedAttack] = []
        for a in mine {
            if a.unscored {
                evaluations.append(Evaluation(expectedId: a.id, classification: .excluded, expectedMidi: a.midi,
                                              measureIndex: a.measureIndex, matchKey: a.matchKey, excludedReason: .unsupportedSpan))
            } else if a.timeUs > cutoff {
                evaluations.append(Evaluation(expectedId: a.id, classification: .excluded, expectedMidi: a.midi,
                                              measureIndex: a.measureIndex, matchKey: a.matchKey, excludedReason: .inputDisconnected))
            } else { open.append(a) }
        }

        // 1. Same-pitch matching.
        var matchedExpected: Set<String> = []
        for pitch in Set(open.map { $0.midi }).sorted() {
            let exp = open.filter { $0.midi == pitch }
            let obsIdx = observed.indices.filter { observed[$0].midi == pitch }
            for (ei, oj) in match(expected: exp.map { $0.timeUs }, observed: obsIdx.map { observed[$0].timeUs }, window: tolerances.acceptUs) {
                let a = exp[ei], oi = obsIdx[oj]
                observed[oi].used = true
                matchedExpected.insert(a.id)
                let err = observed[oi].timeUs - a.timeUs
                let cls: Classification = abs(err) <= tolerances.onTimeUs ? .onTime : (err < 0 ? .early : .late)
                evaluations.append(Evaluation(expectedId: a.id, observedSeqs: [observed[oi].seq], classification: cls, onsetErrorUs: err,
                                              expectedMidi: a.midi, playedMidi: pitch, measureIndex: a.measureIndex, matchKey: a.matchKey))
            }
        }

        // 2. Notes that belong to the hand not being practised are set aside.
        let other = timeline.otherHandAttacks(for: hand)
        for pitch in Set(other.map { $0.midi }).sorted() {
            let exp = other.filter { $0.midi == pitch }
            let obsIdx = observed.indices.filter { observed[$0].midi == pitch && !observed[$0].used }
            for (ei, oj) in match(expected: exp.map { $0.timeUs }, observed: obsIdx.map { observed[$0].timeUs }, window: tolerances.acceptUs) {
                observed[obsIdx[oj]].used = true
                evaluations.append(Evaluation(observedSeqs: [observed[obsIdx[oj]].seq], classification: .excluded, playedMidi: pitch,
                                              measureIndex: exp[ei].measureIndex, excludedReason: .otherHand))
            }
        }

        // 3. A stray note close in time to a missing note is a wrong pitch.
        var unmatched = open.filter { !matchedExpected.contains($0.id) }
        var candidates: [(Int64, String, Int64, Int, Int)] = []
        for (ei, a) in unmatched.enumerated() {
            for oi in observed.indices where !observed[oi].used {
                let dt = abs(observed[oi].timeUs - a.timeUs)
                if dt <= tolerances.acceptUs && abs(observed[oi].midi - a.midi) <= 12 {
                    candidates.append((dt, a.id, observed[oi].seq, ei, oi))
                }
            }
        }
        candidates.sort { ($0.0, $0.1, $0.2) < ($1.0, $1.1, $1.2) }
        var pairedExpected: Set<Int> = []
        for c in candidates where !pairedExpected.contains(c.3) && !observed[c.4].used {
            let a = unmatched[c.3]
            observed[c.4].used = true
            pairedExpected.insert(c.3)
            evaluations.append(Evaluation(expectedId: a.id, observedSeqs: [observed[c.4].seq], classification: .wrongPitch,
                                          onsetErrorUs: observed[c.4].timeUs - a.timeUs, expectedMidi: a.midi, playedMidi: observed[c.4].midi,
                                          octaveError: abs(observed[c.4].midi - a.midi) == 12, measureIndex: a.measureIndex, matchKey: a.matchKey))
        }
        unmatched = unmatched.enumerated().filter { !pairedExpected.contains($0.offset) }.map { $0.element }

        // 4. What is left was missed or extra.
        for a in unmatched {
            evaluations.append(Evaluation(expectedId: a.id, classification: .missed, expectedMidi: a.midi,
                                          measureIndex: a.measureIndex, matchKey: a.matchKey))
        }
        for o in observed where !o.used {
            let measure = timeline.measureIndex(atUs: o.timeUs)
            evaluations.append(Evaluation(observedSeqs: [o.seq], classification: .extra, playedMidi: o.midi, measureIndex: measure))
        }

        evaluations.sort { a, b in
            let ka = (a.expectedId == nil ? 1 : 0, a.expectedId ?? "", a.observedSeqs.first ?? -1)
            let kb = (b.expectedId == nil ? 1 : 0, b.expectedId ?? "", b.observedSeqs.first ?? -1)
            return ka < kb
        }
        return Evaluator.report(mode: .rhythm, evaluations: evaluations, assisted: false)
    }
}
