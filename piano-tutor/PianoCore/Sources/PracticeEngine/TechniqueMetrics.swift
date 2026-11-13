import Foundation
import MusicModel

/// Measurements of how a passage was played, taken from the key and pedal events.
/// These describe the sound that was produced. They say nothing about posture, hand shape or fingering.
public struct TechniqueReport: Codable, Hashable, Sendable {
    /// Spread of timing errors in milliseconds (standard deviation). Lower is more even.
    public var timingSpreadMs: Double?
    /// Spread of key velocities (standard deviation, MIDI units 1–127). Lower is more even.
    public var velocitySpread: Double?
    public var meanVelocity: Double?
    /// Mean overlap between one note's release and the next note's start, in milliseconds.
    /// Positive means the notes join (legato); negative means a gap.
    public var legatoOverlapMs: Double?
    /// Share of note-to-note joins with no gap.
    public var legatoShare: Double?
    /// Mean velocity of the right hand minus the left hand. Positive means the right hand sings out.
    public var handBalance: Double?
    /// Mean gap in milliseconds between the hands when they should play together.
    public var handSyncMs: Double?
    /// Notes whose timing or loudness stands out, as match keys with a short reason.
    public var outliers: [Outlier]

    public struct Outlier: Codable, Hashable, Sendable {
        public var matchKey: String
        public var measureIndex: Int
        public var reason: String
    }
}

public struct PedalReport: Codable, Hashable, Sendable {
    public var cleanChanges: Int
    public var blurredChanges: Int
    public var earlyChanges: Int
    public var details: [String]
}

public enum TechniqueMetrics {
    static func mean(_ v: [Double]) -> Double { v.isEmpty ? 0 : v.reduce(0, +) / Double(v.count) }
    static func stdev(_ v: [Double]) -> Double {
        guard v.count > 1 else { return 0 }
        let m = mean(v)
        return (v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(v.count)).squareRoot()
    }

    /// Measures a graded attempt. Only notes that were matched to the score are used.
    public static func measure(timeline: PassageTimeline, report: AttemptReport, events: [PerformanceEvent]) -> TechniqueReport {
        let attackById = Dictionary(uniqueKeysWithValues: timeline.attacks.map { ($0.id, $0) })
        let eventBySeq = Dictionary(events.map { ($0.seq, $0) }, uniquingKeysWith: { a, _ in a })
        struct Played { var attack: ExpectedAttack; var on: PerformanceEvent; var offUs: Int64? }
        var played: [Played] = []
        for e in report.evaluations where [.hit, .onTime, .early, .late].contains(e.classification) {
            guard let id = e.expectedId, let a = attackById[id], let seq = e.observedSeqs.first, let on = eventBySeq[seq] else { continue }
            let off = events.first(where: { $0.type == .noteOff && $0.pitch == a.midi && ($0.timeUs, $0.seq) > (on.timeUs, on.seq) })
            played.append(Played(attack: a, on: on, offUs: off?.timeUs))
        }
        played.sort { ($0.attack.timeUs, $0.attack.midi) < ($1.attack.timeUs, $1.attack.midi) }

        var result = TechniqueReport(outliers: [])
        guard played.count >= 2 else { return result }

        let velocities = played.compactMap { $0.on.velocity }.map(Double.init)
        if !velocities.isEmpty {
            result.meanVelocity = mean(velocities)
            result.velocitySpread = stdev(velocities)
        }

        var errorsMs: [Double] = []
        if report.mode == .rhythm {
            errorsMs = played.map { Double($0.on.timeUs - $0.attack.timeUs) / 1000 }
        } else if let first = played.first, let last = played.last, last.attack.timeUs > first.attack.timeUs {
            // Wait mode has no fixed beat: compare against the learner's own average speed.
            let scale = Double(last.on.timeUs - first.on.timeUs) / Double(last.attack.timeUs - first.attack.timeUs)
            errorsMs = played.map {
                (Double($0.on.timeUs - first.on.timeUs) - Double($0.attack.timeUs - first.attack.timeUs) * scale) / 1000
            }
        }
        if !errorsMs.isEmpty {
            let spread = stdev(errorsMs)
            result.timingSpreadMs = spread
            let m = mean(errorsMs)
            for (p, err) in zip(played, errorsMs) where spread > 0 && abs(err - m) > max(2 * spread, 40) {
                result.outliers.append(.init(matchKey: p.attack.matchKey, measureIndex: p.attack.measureIndex,
                                             reason: err > m ? "late" : "early"))
            }
        }
        if let vs = result.velocitySpread, let vm = result.meanVelocity, vs > 0 {
            for p in played {
                guard let v = p.on.velocity else { continue }
                if Double(v) - vm > max(2 * vs, 20) {
                    result.outliers.append(.init(matchKey: p.attack.matchKey, measureIndex: p.attack.measureIndex, reason: "louder"))
                }
            }
        }

        // Legato: within each hand, from each single note to the next single note.
        var overlaps: [Double] = []
        for hand in [Hand.right, Hand.left] {
            let line = played.filter { $0.attack.hand == hand }
            var groups: [[Played]] = []
            for p in line {
                if let last = groups.last, last[0].attack.timeUs == p.attack.timeUs { groups[groups.count - 1].append(p) } else { groups.append([p]) }
            }
            for (a, b) in zip(groups, groups.dropFirst()) where a.count == 1 && b.count == 1 {
                // Only when the score has no rest between the two notes.
                guard a[0].attack.timeUs + a[0].attack.durationUs >= b[0].attack.timeUs, let off = a[0].offUs else { continue }
                overlaps.append(Double(off - b[0].on.timeUs) / 1000)
            }
        }
        if !overlaps.isEmpty {
            result.legatoOverlapMs = mean(overlaps)
            result.legatoShare = Double(overlaps.filter { $0 >= 0 }.count) / Double(overlaps.count)
        }

        let right = played.filter { $0.attack.hand == .right }.compactMap { $0.on.velocity }.map(Double.init)
        let left = played.filter { $0.attack.hand == .left }.compactMap { $0.on.velocity }.map(Double.init)
        if !right.isEmpty && !left.isEmpty { result.handBalance = mean(right) - mean(left) }

        var syncs: [Double] = []
        for (_, together) in Dictionary(grouping: played, by: { $0.attack.timeUs }) {
            let r = together.filter { $0.attack.hand == .right }.map { Double($0.on.timeUs) }
            let l = together.filter { $0.attack.hand == .left }.map { Double($0.on.timeUs) }
            if !r.isEmpty && !l.isEmpty { syncs.append(abs(mean(r) - mean(l)) / 1000) }
        }
        if !syncs.isEmpty { result.handSyncMs = mean(syncs) }
        return result
    }

    /// Checks pedal changes against the moments the harmony changes.
    /// A clean change lifts the pedal at or just after the new chord and presses it again.
    public static func pedal(changeTimesUs: [Int64], events: [PerformanceEvent]) -> PedalReport {
        var transitions: [(Int64, Bool)] = []
        var down = false
        for e in events.sorted(by: { ($0.timeUs, $0.seq) < ($1.timeUs, $1.seq) }) where e.type == .pedal {
            let now = (e.pedalValue ?? 0) >= 64
            if now != down { transitions.append((e.timeUs, now)); down = now }
        }
        var report = PedalReport(cleanChanges: 0, blurredChanges: 0, earlyChanges: 0, details: [])
        for (i, t) in changeTimesUs.enumerated() {
            let lifts = transitions.filter { !$0.1 && $0.0 >= t - 150_000 && $0.0 <= t + 300_000 }
            guard let lift = lifts.first else {
                let heldThrough = transitions.last(where: { $0.0 < t - 150_000 })?.1 ?? false
                if heldThrough { report.blurredChanges += 1; report.details.append("Change \(i + 1): pedal held through, harmonies blur") }
                continue
            }
            let press = transitions.first(where: { $0.1 && $0.0 > lift.0 })
            if let press, press.0 < t - 20_000 {
                report.earlyChanges += 1
                report.details.append("Change \(i + 1): pedal back down before the new chord sounded")
            } else {
                report.cleanChanges += 1
            }
        }
        return report
    }
}
