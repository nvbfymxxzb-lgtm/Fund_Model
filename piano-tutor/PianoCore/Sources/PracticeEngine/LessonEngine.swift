import Foundation
import MusicModel

/// One step on the way to learning a song.
public struct LearningStep: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case listen, phrase, join, trouble, wholeSlow, wholeFull, perform }
    public var id: String
    public var kind: Kind
    public var title: String
    public var detail: String
    public var firstMeasure: Int
    public var lastMeasure: Int
    public var hand: HandSelection
    public var mode: PracticeMode
    public var tempoPercent: Int
}

public enum LearningPath {
    /// Splits a score into phrases of about four measures. A pickup joins the first phrase.
    public static func autoPhrases(_ score: Score, size: Int = 4) -> [ClosedRange<Int>] {
        guard !score.measures.isEmpty else { return [] }
        var ranges: [ClosedRange<Int>] = []
        var start = 0
        let offset = (score.measures.first?.isPickup ?? false) ? 1 : 0
        var i = offset
        while i < score.measures.count {
            let end = min(i + size - 1, score.measures.count - 1)
            ranges.append(start...end)
            start = end + 1
            i = end + 1
        }
        if ranges.isEmpty { ranges = [0...(score.measures.count - 1)] }
        // Fold a short tail into the phrase before it.
        if ranges.count > 1, let last = ranges.last, last.count < 2 {
            ranges.removeLast()
            ranges[ranges.count - 1] = ranges[ranges.count - 1].lowerBound...last.upperBound
        }
        return ranges
    }

    public static func generate(score: Score, phrases: [ClosedRange<Int>]? = nil, troubleSpots: [ClosedRange<Int>] = []) -> [LearningStep] {
        let phrases = phrases ?? autoPhrases(score)
        guard let lastMeasure = score.measures.last?.index else { return [] }
        let hasLeft = score.notes.contains { $0.hand == .left && !$0.isGrace }
        let hasRight = score.notes.contains { $0.hand == .right && !$0.isGrace }
        let twoHands = hasLeft && hasRight
        func label(_ r: ClosedRange<Int>) -> String {
            let a = score.measures[r.lowerBound].number, b = score.measures[r.upperBound].number
            return a == b ? "measure \(a)" : "measures \(a)–\(b)"
        }
        var steps: [LearningStep] = []
        steps.append(LearningStep(id: "listen", kind: .listen, title: "Listen", detail: "Hear the whole piece and follow the notes.",
                                  firstMeasure: 0, lastMeasure: lastMeasure, hand: .both, mode: .wait, tempoPercent: 100))
        for (pi, r) in phrases.enumerated() {
            let name = "Phrase \(pi + 1)"
            if twoHands {
                steps.append(LearningStep(id: "p\(pi).rh", kind: .phrase, title: "\(name): right hand", detail: "Find the notes of \(label(r)). The music waits for you.",
                                          firstMeasure: r.lowerBound, lastMeasure: r.upperBound, hand: .right, mode: .wait, tempoPercent: 100))
                steps.append(LearningStep(id: "p\(pi).lh", kind: .phrase, title: "\(name): left hand", detail: "Now the left hand of \(label(r)).",
                                          firstMeasure: r.lowerBound, lastMeasure: r.upperBound, hand: .left, mode: .wait, tempoPercent: 100))
            }
            steps.append(LearningStep(id: "p\(pi).both.wait", kind: .phrase, title: twoHands ? "\(name): hands together" : "\(name): find the notes",
                                      detail: "Play \(label(r)) at your own pace.",
                                      firstMeasure: r.lowerBound, lastMeasure: r.upperBound, hand: .both, mode: .wait, tempoPercent: 100))
            steps.append(LearningStep(id: "p\(pi).both.60", kind: .phrase, title: "\(name): in time, slowly", detail: "Play \(label(r)) with the beat at 60% speed.",
                                      firstMeasure: r.lowerBound, lastMeasure: r.upperBound, hand: .both, mode: .rhythm, tempoPercent: 60))
            steps.append(LearningStep(id: "p\(pi).both.80", kind: .phrase, title: "\(name): nearly full speed", detail: "Play \(label(r)) with the beat at 80% speed.",
                                      firstMeasure: r.lowerBound, lastMeasure: r.upperBound, hand: .both, mode: .rhythm, tempoPercent: 80))
            if pi > 0 && pi % 2 == 1 {
                let joined = phrases[pi - 1].lowerBound...r.upperBound
                steps.append(LearningStep(id: "j\(pi)", kind: .join, title: "Join phrases \(pi) and \(pi + 1)", detail: "Play \(label(joined)) without stopping, at 70% speed.",
                                          firstMeasure: joined.lowerBound, lastMeasure: joined.upperBound, hand: .both, mode: .rhythm, tempoPercent: 70))
            }
        }
        for (ti, r) in troubleSpots.enumerated() {
            steps.append(LearningStep(id: "t\(ti)", kind: .trouble, title: "Hardest spot \(ti + 1)", detail: "Extra work on \(label(r)), slowly.",
                                      firstMeasure: r.lowerBound, lastMeasure: r.upperBound, hand: .both, mode: .rhythm, tempoPercent: 60))
        }
        steps.append(LearningStep(id: "whole.70", kind: .wholeSlow, title: "Whole piece, slowly", detail: "Everything joined up at 70% speed.",
                                  firstMeasure: 0, lastMeasure: lastMeasure, hand: .both, mode: .rhythm, tempoPercent: 70))
        steps.append(LearningStep(id: "whole.100", kind: .wholeFull, title: "Whole piece, full speed", detail: "The whole piece at the written tempo.",
                                  firstMeasure: 0, lastMeasure: lastMeasure, hand: .both, mode: .rhythm, tempoPercent: 100))
        steps.append(LearningStep(id: "perform", kind: .perform, title: "Perform", detail: "Play it through once more, for the music: shape the loud and soft, and keep the melody singing.",
                                  firstMeasure: 0, lastMeasure: lastMeasure, hand: .both, mode: .rhythm, tempoPercent: 100))
        return steps
    }
}

/// What the app suggests after an attempt.
public struct Suggestion: Codable, Hashable, Sendable {
    public enum Action: String, Codable, Sendable { case nextStep, repeatSame, speedUp, slowDown, shortenLoop, oneHand, checkConnection }
    public var action: Action
    public var message: String
    public var tempoPercent: Int?
    public var firstMeasure: Int?
    public var lastMeasure: Int?
    public var hand: HandSelection?

    public init(action: Action, message: String, tempoPercent: Int? = nil, firstMeasure: Int? = nil, lastMeasure: Int? = nil, hand: HandSelection? = nil) {
        self.action = action; self.message = message; self.tempoPercent = tempoPercent
        self.firstMeasure = firstMeasure; self.lastMeasure = lastMeasure; self.hand = hand
    }
}

/// Tracks a run of attempts on one passage and decides what to suggest next.
public struct Coach: Codable, Hashable, Sendable {
    public private(set) var consecutivePasses = 0
    public private(set) var consecutiveFails = 0
    public init() {}

    public mutating func reset() { consecutivePasses = 0; consecutiveFails = 0 }

    public mutating func record(_ report: AttemptReport, score: Score, firstMeasure: Int, lastMeasure: Int,
                                hand: HandSelection, tempoPercent: Int) -> Suggestion {
        switch report.result {
        case .inconclusive:
            return Suggestion(action: .checkConnection, message: "Too much of that run could not be graded, so it does not count either way. Check the piano connection and try again.")
        case .pass:
            consecutivePasses += 1; consecutiveFails = 0
            if report.mode == .rhythm && tempoPercent < 100 && consecutivePasses >= 2 && !report.assisted {
                let next = min(100, tempoPercent + 5)
                return Suggestion(action: .speedUp, message: "Two clean runs in a row. Try it a little faster, at \(next)%.", tempoPercent: next)
            }
            if consecutivePasses >= 2 || report.mode == .wait {
                return Suggestion(action: .nextStep, message: report.assisted ? "You got there with hints. Try once more without them, or move on." : "That was secure. Move on to the next step.")
            }
            return Suggestion(action: .repeatSame, message: "Clean run. Play it once more to make sure it was not luck.")
        case .fail:
            consecutiveFails += 1; consecutivePasses = 0
            let name: (Int) -> String = { score.measures.indices.contains($0) ? score.measures[$0].number : "\($0 + 1)" }
            if consecutiveFails >= 3 {
                consecutiveFails = 0
                if let worst = report.troubleMeasures.first, lastMeasure - firstMeasure >= 2 {
                    let a = max(firstMeasure, worst), b = min(lastMeasure, worst + 1)
                    return Suggestion(action: .shortenLoop, message: "Measure \(name(worst)) keeps catching you. Loop just measures \(name(a))–\(name(b)) until it settles.",
                                      firstMeasure: a, lastMeasure: b)
                }
                if report.mode == .rhythm && tempoPercent > 50 {
                    let slower = max(50, tempoPercent - 10)
                    return Suggestion(action: .slowDown, message: "Slow down to \(slower)% and get it right before speeding up again.", tempoPercent: slower)
                }
                if hand == .both {
                    return Suggestion(action: .oneHand, message: "Go back to one hand at a time for this passage.", hand: .right)
                }
            }
            if let worst = report.troubleMeasures.first {
                let missed = report.evaluations.filter { $0.measureIndex == worst && ($0.classification == .missed || $0.classification == .wrongPitch) }
                if let m = missed.first, let midi = m.expectedMidi {
                    let wrong = m.classification == .wrongPitch && m.playedMidi != nil
                    let text = wrong
                        ? "In measure \(name(worst)) you played \(MIDINote.name(m.playedMidi!)) where \(MIDINote.name(midi)) is written\(m.octaveError ? " (right note, wrong octave)" : "")."
                        : "In measure \(name(worst)) the \(MIDINote.name(midi)) was missed."
                    return Suggestion(action: .repeatSame, message: text + " Try again.")
                }
                let timing = report.evaluations.filter { $0.measureIndex == worst && ($0.classification == .late || $0.classification == .early) }
                if !timing.isEmpty {
                    let late = timing.filter { $0.classification == .late }.count * 2 >= timing.count
                    return Suggestion(action: .repeatSame, message: "The notes were right but \(late ? "late" : "early") in measure \(name(worst)). Listen to the beat and try again.")
                }
                if report.extraCount > 0 {
                    return Suggestion(action: .repeatSame, message: "There were \(report.extraCount) extra notes, most around measure \(name(worst)). Try again and play only what is written.")
                }
            }
            return Suggestion(action: .repeatSame, message: "Not quite. Try again.")
        }
    }
}

/// Saved progress on one song.
public struct SongProgress: Codable, Hashable, Sendable {
    public var songId: String
    public var completedSteps: Set<String> = []
    public var bestFullTempoPercent: Int = 0
    public var lastPracticed: Date?
    public var attempts: Int = 0
    public var userRating: Int?         // 1 too easy … 5 too hard

    public init(songId: String) { self.songId = songId }

    public func fraction(of steps: [LearningStep]) -> Double {
        steps.isEmpty ? 0 : Double(steps.filter { completedSteps.contains($0.id) }.count) / Double(steps.count)
    }
    public func nextStep(in steps: [LearningStep]) -> LearningStep? { steps.first { !completedSteps.contains($0.id) } }
}
