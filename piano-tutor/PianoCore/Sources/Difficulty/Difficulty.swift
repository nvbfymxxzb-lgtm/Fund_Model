import Foundation
import MusicModel

/// How hard a score is, with the reasons.
public struct DifficultyReport: Codable, Hashable, Sendable {
    public static let version = "difficulty-1"
    public var version = DifficultyReport.version
    /// 0 (easiest) to 100.
    public var score: Double
    /// Level 1–6 estimated from the score.
    public var estimatedLevel: Int
    /// Each measured feature, scaled 0–1.
    public var features: [String: Double]
    /// The three things that add most to the difficulty, in plain words.
    public var topReasons: [String]
    /// The hardest two-measure stretches, as measure index ranges.
    public var hardestWindows: [ClosedRange<Int>]
}

public enum DifficultyAnalyzer {
    struct Feature { let key: String; let weight: Double; let low: Double; let high: Double; let reason: (Double) -> String }

    // Weights and ranges are first estimates, to be tuned against graded repertoire.
    static let features: [Feature] = [
        Feature(key: "density", weight: 18, low: 1.0, high: 7.0) { String(format: "fast notes (up to %.0f a second)", $0) },
        Feature(key: "rhythm", weight: 12, low: 0.0, high: 1.0) { _ in "tricky rhythms" },
        Feature(key: "independence", weight: 16, low: 0.15, high: 0.75) { _ in "the hands move independently" },
        Feature(key: "chords", weight: 8, low: 1.0, high: 4.0) { String(format: "chords of up to %.0f notes in one hand", $0) },
        Feature(key: "stretch", weight: 8, low: 7.0, high: 14.0) { $0 > 12 ? "stretches wider than an octave" : "wide hand stretches" },
        Feature(key: "leaps", weight: 14, low: 4.0, high: 24.0) { _ in "quick leaps across the keys" },
        Feature(key: "shifts", weight: 8, low: 0.2, high: 2.5) { _ in "frequent changes of hand position" },
        Feature(key: "key", weight: 10, low: 0.0, high: 5.0) { _ in "sharps or flats to remember" },
        Feature(key: "voices", weight: 4, low: 1.0, high: 2.0) { _ in "two melodic lines in one hand" },
        Feature(key: "length", weight: 2, low: 8.0, high: 64.0) { String(format: "length (%.0f measures)", $0) },
    ]

    static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded()))]
    }

    struct Group { let timeUs: Int64; let measure: Int; let pitches: [Int] }

    static func groups(_ attacks: [ExpectedAttack]) -> [Group] {
        var result: [Group] = []
        for (time, items) in Dictionary(grouping: attacks, by: { $0.timeUs }).sorted(by: { $0.key < $1.key }) {
            result.append(Group(timeUs: time, measure: items[0].measureIndex, pitches: items.map { $0.midi }.sorted()))
        }
        return result
    }

    /// Raw measurements for a set of measures.
    static func raw(_ score: Score, timeline: PassageTimeline, measures: Set<Int>?) -> [String: Double] {
        let attacks = timeline.attacks.filter { measures == nil || measures!.contains($0.measureIndex) }
        let notes = score.notes.filter { !$0.isGrace && (measures == nil || measures!.contains($0.measureIndex)) }
        var out: [String: Double] = [:]
        guard !attacks.isEmpty else { return out }
        let right = groups(attacks.filter { $0.hand == .right }), left = groups(attacks.filter { $0.hand == .left })

        // Fastest stretch: attacks per second in one hand over two-second windows.
        var densities: [Double] = []
        for hand in [right, left] where !hand.isEmpty {
            let times = hand.map { $0.timeUs }
            for (i, t) in times.enumerated() {
                let count = times[i...].prefix { $0 < t + 2_000_000 }.count
                densities.append(Double(count) / 2.0)
            }
        }
        out["density"] = percentile(densities, 0.9)

        // Rhythm: off-beat starts, short values, triplets and dotted notes.
        var offBeat = 0, total = 0, tuplets = 0, dotted = 0, short = 0
        let lengthByMeasure = Dictionary(uniqueKeysWithValues: score.measures.map { ($0.index, $0) })
        for n in notes where n.isAttack {
            guard let m = lengthByMeasure[n.measureIndex] else { continue }
            total += 1
            let inBeat = n.onset / m.time.beatLength
            if inBeat.d != 1 && inBeat.d != 2 { offBeat += 1 }
            if n.duration.d % 3 == 0 { tuplets += 1 }
            if n.duration.n == 3 { dotted += 1 }
            if n.duration < Rational(1, 8) { short += 1 }
        }
        let t = Double(max(total, 1))
        out["rhythm"] = min(1, 2.5 * Double(offBeat) / t + 1.5 * Double(tuplets) / t + 0.8 * Double(dotted) / t + 1.2 * Double(short) / t)

        // Independence: moments when only one hand plays while the other is active elsewhere.
        if !right.isEmpty && !left.isEmpty {
            let r = Set(right.map { $0.timeUs }), l = Set(left.map { $0.timeUs })
            let together = r.intersection(l).count
            let smaller = min(r.count, l.count)
            out["independence"] = smaller == 0 ? 0 : 1 - Double(together) / Double(r.union(l).count) - (Double(abs(r.count - l.count)) / Double(r.union(l).count)) * 0.6
            out["independence"] = max(0, out["independence"]!)
        } else { out["independence"] = 0 }

        let all = right + left
        out["chords"] = Double(all.map { $0.pitches.count }.max() ?? 1)
        out["stretch"] = Double(all.map { ($0.pitches.last ?? 0) - ($0.pitches.first ?? 0) }.max() ?? 0)

        // Leaps: semitones travelled per second between one position and the next.
        var leaps: [Double] = [], shifts = 0
        for hand in [right, left] {
            for (a, b) in zip(hand, hand.dropFirst()) {
                let gap = max(Double(b.timeUs - a.timeUs) / 1_000_000, 0.05)
                // Distance the hand must travel beyond what it already covers.
                let up = Double((b.pitches.last ?? 0) - (a.pitches.last ?? 0)), down = Double((a.pitches.first ?? 0) - (b.pitches.first ?? 0))
                let move = max(up, down, 0)
                if move > 4 { leaps.append(move / gap) }
                if move > 7 { shifts += 1 }
            }
        }
        out["leaps"] = percentile(leaps, 0.9)
        let measureCount = Double(Set(attacks.map { $0.measureIndex }).count)
        out["shifts"] = Double(shifts) / max(measureCount, 1)

        // Key: signature accidentals plus notes outside the key.
        let fifths = score.measures.first?.keyFifths ?? 0
        let sharpOrder: [Step] = [.f, .c, .g, .d, .a, .e, .b]
        func signatureAlter(_ step: Step) -> Int {
            if fifths > 0, let i = sharpOrder.firstIndex(of: step), i < fifths { return 1 }
            if fifths < 0, let i = Array(sharpOrder.reversed()).firstIndex(of: step), i < -fifths { return -1 }
            return 0
        }
        let chromatic = notes.filter { $0.pitch.alter != signatureAlter($0.pitch.step) }.count
        out["key"] = Double(abs(fifths)) + 6 * Double(chromatic) / Double(max(notes.count, 1))

        var maxVoices = 1
        for (_, ms) in Dictionary(grouping: notes, by: { "\($0.measureIndex)|\($0.staff)" }) { maxVoices = max(maxVoices, Set(ms.map { $0.voice }).count) }
        out["voices"] = Double(maxVoices)
        out["length"] = Double(timeline.measureIndexes.count)
        return out
    }

    static func scaled(_ raw: [String: Double]) -> [String: Double] {
        var out: [String: Double] = [:]
        for f in features {
            let v = raw[f.key] ?? f.low
            out[f.key] = min(1, max(0, (v - f.low) / (f.high - f.low)))
        }
        return out
    }

    static func total(_ scaled: [String: Double]) -> Double {
        let weightSum = features.reduce(0) { $0 + $1.weight }
        return 100 * features.reduce(0) { $0 + $1.weight * (scaled[$1.key] ?? 0) } / weightSum
    }

    /// Level boundaries on the 0–100 score. Fitted to the eleven bundled songs, so treat them as rough.
    public static let levelBoundaries: [Double] = [19, 24, 38, 50, 70]

    public static func level(for score: Double) -> Int { 1 + levelBoundaries.filter { score >= $0 }.count }

    public static func analyze(_ score: Score) -> DifficultyReport {
        let timeline = score.timeline(passage: score.wholePassage)
        let rawValues = raw(score, timeline: timeline, measures: nil)
        let scaledValues = scaled(rawValues)
        let value = total(scaledValues)

        let reasons = features
            .map { (f: $0, contribution: $0.weight * (scaledValues[$0.key] ?? 0)) }
            .filter { $0.contribution > 0.5 && $0.f.key != "length" }
            .sorted { ($0.contribution, $0.f.key) > ($1.contribution, $1.f.key) }
            .prefix(3)
            .map { $0.f.reason(rawValues[$0.f.key] ?? 0) }

        // Hardest two-measure windows.
        var windows: [(Double, ClosedRange<Int>)] = []
        let indexes = score.measures.map { $0.index }
        if indexes.count > 2 {
            for i in 0..<(indexes.count - 1) {
                let w = raw(score, timeline: timeline, measures: [indexes[i], indexes[i + 1]])
                guard !w.isEmpty else { continue }
                var s = scaled(w); s["length"] = 0; s["key"] = 0
                windows.append((total(s), indexes[i]...indexes[i + 1]))
            }
        }
        windows.sort { ($0.0, -$0.1.lowerBound) > ($1.0, -$1.1.lowerBound) }
        var chosen: [ClosedRange<Int>] = []
        for w in windows where chosen.count < 2 && w.0 > 0 {
            if !chosen.contains(where: { $0.overlaps(w.1) }) { chosen.append(w.1) }
        }

        return DifficultyReport(score: (value * 10).rounded() / 10, estimatedLevel: level(for: value), features: scaledValues,
                                topReasons: Array(reasons), hardestWindows: chosen.sorted { $0.lowerBound < $1.lowerBound })
    }
}
