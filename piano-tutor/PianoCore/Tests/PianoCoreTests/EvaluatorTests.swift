import XCTest
import Foundation
@testable import MusicModel
@testable import PracticeEngine

final class WaitModeTests: XCTestCase {
    func session(_ rh: String, _ lh: String = "", hand: HandSelection = .both, strict: Bool = true) throws -> WaitModeSession {
        let s = try tiny(rh, lh)
        var tol = Tolerances(); tol.strictChords = strict
        return WaitModeSession(timeline: s.timeline(passage: s.wholePassage), hand: hand, tolerances: tol)
    }

    func testAdvancesOnlyOnRightNotes() throws {
        var w = try session("C4:q D4 E4 F4", hand: .right)
        XCTAssertEqual(w.handle(.noteOn(60, at: 0, seq: 1)), .correct(midi: 60, groupComplete: true))
        XCTAssertEqual(w.handle(.noteOn(61, at: 1, seq: 2)), .wrong(midi: 61, octaveError: false))
        XCTAssertEqual(w.handle(.noteOn(74, at: 2, seq: 3)), .wrong(midi: 74, octaveError: true))
        XCTAssertEqual(w.index, 1)
        XCTAssertEqual(w.handle(.noteOn(62, at: 3, seq: 4)), .correct(midi: 62, groupComplete: true))
        _ = w.handle(.noteOn(64, at: 4, seq: 5)); _ = w.handle(.noteOn(65, at: 5, seq: 6))
        XCTAssertTrue(w.isFinished)
        let r = w.report()
        XCTAssertEqual(r.matchedCount, 4); XCTAssertEqual(r.wrongCount, 2)
        XCTAssertEqual(r.result, .fail, "two wrong notes in four is not a clean run")
    }

    func testHeldKeyDoesNotSatisfyRepeatedNotes() throws {
        // T03: one key press, held. Only events count, so three of the four Cs stay unplayed.
        var w = try session("C4:q C4 C4 C4", hand: .right)
        _ = w.handle(.noteOn(60, at: 0, seq: 1))
        XCTAssertEqual(w.index, 1)
        let r = w.report()
        XCTAssertEqual(r.matchedCount, 1); XCTAssertEqual(r.missedCount, 3)
    }

    func testChordPolicies() throws {
        // T08: a chord rolled over 300 ms.
        var strict = try session("[C4 E4 G4]:w", hand: .right)
        XCTAssertEqual(strict.handle(.noteOn(60, at: 0, seq: 1)), .correct(midi: 60, groupComplete: false))
        XCTAssertEqual(strict.handle(.noteOn(64, at: 150_000, seq: 2)), .chordTooSpread(midi: 64))
        XCTAssertEqual(strict.handle(.noteOn(67, at: 300_000, seq: 3)), .chordTooSpread(midi: 67))
        XCTAssertFalse(strict.isFinished)
        var easy = try session("[C4 E4 G4]:w", hand: .right, strict: false)
        _ = easy.handle(.noteOn(60, at: 0, seq: 1)); _ = easy.handle(.noteOn(64, at: 150_000, seq: 2))
        XCTAssertEqual(easy.handle(.noteOn(67, at: 300_000, seq: 3)), .correct(midi: 67, groupComplete: true))
        XCTAssertEqual(easy.report().result, .pass)
    }

    func testOtherHandNotesAreNotMistakes() throws {
        // T12: practising the right hand while also playing the left.
        var w = try session("C4:q D4 E4 F4", "C3:h G3", hand: .right)
        XCTAssertEqual(w.handle(.noteOn(48, at: 0, seq: 1)), .otherHand(midi: 48))
        _ = w.handle(.noteOn(60, at: 1, seq: 2)); _ = w.handle(.noteOn(62, at: 2, seq: 3))
        XCTAssertEqual(w.handle(.noteOn(55, at: 3, seq: 4)), .otherHand(midi: 55))
        _ = w.handle(.noteOn(64, at: 4, seq: 5)); _ = w.handle(.noteOn(65, at: 5, seq: 6))
        XCTAssertEqual(w.report().result, .pass)
        XCTAssertEqual(w.report().wrongCount, 0)
    }

    func testHintAfterThreeWrongNotes() throws {
        var w = try session("C4:w", hand: .right)
        for i in 0..<3 { _ = w.handle(.noteOn(61, at: Int64(i), seq: Int64(i))) }
        XCTAssertTrue(w.needsHint)
        _ = w.handle(.noteOn(60, at: 9, seq: 9))
        XCTAssertTrue(w.report().assisted)
    }

    func testDisconnectPausesAndNeverPenalises() throws {
        var w = try session("C4:q D4 E4 F4", hand: .right)
        _ = w.handle(.noteOn(60, at: 0, seq: 1))
        XCTAssertEqual(w.handle(PerformanceEvent(seq: 2, type: .disconnect, timeUs: 5)), .paused)
        XCTAssertEqual(w.handle(.noteOn(62, at: 6, seq: 3)), .paused)
        let r = w.report()
        XCTAssertEqual(r.missedCount, 0); XCTAssertEqual(r.result, .inconclusive)
        w.resume()
        XCTAssertEqual(w.handle(.noteOn(62, at: 7, seq: 4)), .correct(midi: 62, groupComplete: true))
    }
}

final class RhythmModeTests: XCTestCase {
    var score: Score!
    var timeline: PassageTimeline!

    override func setUpWithError() throws {
        score = try tiny(twoHandPiece.rh, twoHandPiece.lh)
        timeline = score.timeline(passage: score.wholePassage)
    }

    func grade(_ events: [PerformanceEvent], hand: HandSelection = .both) -> AttemptReport {
        RhythmEvaluator.evaluate(timeline: timeline, hand: hand, events: events)
    }

    func testPerfectPerformancePasses() {
        // T01
        let r = grade(play(timeline))
        XCTAssertEqual(r.result, .pass)
        XCTAssertEqual(r.matchedCount, r.scoredCount); XCTAssertEqual(r.onTimeCount, r.scoredCount)
        XCTAssertEqual(r.extraCount, 0); XCTAssertEqual(r.missedCount, 0)
    }

    func testCorrectMelodyOverWrongBassFails() {
        // T02
        let events = renumber(play(timeline).map { e in
            var e = e; if let p = e.pitch, p < 60 { e.pitch = p + 1 }; return e
        })
        let r = grade(events)
        XCTAssertEqual(r.result, .fail)
        XCTAssertEqual(r.evaluations.filter { $0.classification == .wrongPitch }.count, timeline.attacks(for: .left).count)
        XCTAssertEqual(r.evaluations.filter { [.onTime].contains($0.classification) }.count, timeline.attacks(for: .right).count)
    }

    func testOctaveErrorIsNamed() {
        // T05
        var events = play(timeline, hand: .right)
        let target = timeline.attacks(for: .right)[5]
        events = renumber(events.map { e in var e = e; if e.pitch == target.midi && abs(e.timeUs - target.timeUs) < 600_000 && e.timeUs >= target.timeUs { e.pitch = target.midi + 12 }; return e })
        let r = grade(events, hand: .right)
        let wrong = r.evaluations.filter { $0.classification == .wrongPitch }
        XCTAssertEqual(wrong.count, 1); XCTAssertTrue(wrong[0].octaveError)
        XCTAssertEqual(wrong[0].measureIndex, 1)
        XCTAssertEqual(r.result, .fail)
    }

    func testSkippedMeasureDoesNotCascade() {
        // T06: measure 3 (index 2) left out; everything after must still match.
        let events = renumber(play(timeline).filter { timeline.measureIndex(atUs: $0.timeUs) != 2 || $0.type != .noteOn })
        let r = grade(events)
        let missed = r.evaluations.filter { $0.classification == .missed }
        XCTAssertFalse(missed.isEmpty)
        XCTAssertTrue(missed.allSatisfy { $0.measureIndex == 2 })
        XCTAssertEqual(r.troubleMeasures.first, 2)
        XCTAssertEqual(r.result, .fail)
    }

    func testMashingExtraNotesNeverPasses() {
        // T07
        var events = play(timeline)
        for i in 0..<20 { events.append(.noteOn(90 + (i % 5), at: Int64(i) * 350_000 + 120_000)) }
        let r = grade(renumber(events))
        XCTAssertEqual(r.matchedCount, r.scoredCount)
        XCTAssertEqual(r.extraCount, 20)
        XCTAssertEqual(r.result, .fail)
    }

    func testOnePlayedNoteCannotSatisfyTwoExpected() throws {
        let s = try tiny("C4:e C4 C4 C4 C4:h")
        let t = s.timeline(passage: s.wholePassage)
        let r = RhythmEvaluator.evaluate(timeline: t, hand: .right, events: [.noteOn(60, at: 100_000, seq: 1)])
        XCTAssertEqual(r.matchedCount, 1); XCTAssertEqual(r.missedCount, 4)
    }

    func testConsistentlyLateIsNotAPass() {
        // T09: right notes, 150 ms late throughout.
        let events = renumber(play(timeline).map { e in var e = e; e.timeUs += 150_000; return e })
        let r = grade(events)
        XCTAssertEqual(r.matchedCount, r.scoredCount)
        XCTAssertEqual(r.onTimeCount, 0)
        XCTAssertTrue(r.evaluations.filter { $0.expectedId != nil }.allSatisfy { $0.classification == .late })
        XCTAssertEqual(r.result, .fail)
        // The same performance with the measured delay calibrated out passes.
        var tol = Tolerances(); tol.calibrationOffsetUs = 150_000
        XCTAssertEqual(RhythmEvaluator.evaluate(timeline: timeline, hand: .both, events: events, tolerances: tol).result, .pass)
    }

    func testHalfABeatLateIsOutsideTheWindow() {
        let events = renumber(play(timeline, hand: .right).map { e in var e = e; e.timeUs += 250_000; return e })
        let r = grade(events, hand: .right)
        XCTAssertEqual(r.result, .fail)
        XCTAssertLessThan(r.onTimeCount, r.scoredCount / 4)
    }

    func testDisconnectExcludesTheRest() {
        // T10: connection drops at the start of measure 3.
        let dropAt = timeline.measureStartsUs[2]
        var events = play(timeline).filter { $0.timeUs < dropAt }
        events.append(PerformanceEvent(seq: 0, type: .disconnect, timeUs: dropAt + 50_000))
        let r = grade(renumber(events))
        XCTAssertEqual(r.missedCount, 0, "a dropped connection never adds missed notes")
        XCTAssertGreaterThan(r.excludedCount, 0)
        XCTAssertTrue(r.evaluations.filter { $0.classification == .excluded }.allSatisfy { $0.excludedReason == .inputDisconnected })
        XCTAssertEqual(r.result, .inconclusive)
    }

    func testOneHandPracticeIgnoresTheOtherHand() {
        // T12
        let r = grade(play(timeline), hand: .right)
        XCTAssertEqual(r.result, .pass); XCTAssertEqual(r.extraCount, 0)
        XCTAssertEqual(r.evaluations.filter { $0.excludedReason == .otherHand }.count, timeline.attacks(for: .left).count)
    }

    func testRepeatsAreFollowed() throws {
        // T13
        let s = try tiny("|: C4:h D4 | E4:h C4 :| G4:w")
        let t = s.timeline(passage: s.wholePassage)
        let r = RhythmEvaluator.evaluate(timeline: t, hand: .right, events: play(t, hand: .right))
        XCTAssertEqual(r.scoredCount, 9); XCTAssertEqual(r.result, .pass)
    }

    func testGradingIsDeterministic() throws {
        var events = play(timeline)
        for i in stride(from: 0, to: events.count, by: 7) { events[i].timeUs += Int64((i * 37) % 180_000) - 60_000 }
        events.append(.noteOn(61, at: 700_000)); events.append(.noteOn(48, at: 2_050_000))
        events = renumber(events)
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let a = try enc.encode(grade(events))
        let b = try enc.encode(grade(events.reversed()))
        let trace = PerformanceTrace(header: TraceHeader(songId: "t", passage: timeline.passage, hand: .both, mode: .rhythm, tempoPercent: 100), events: events)
        let replayed = try PerformanceTrace(jsonLines: try trace.jsonLines())
        let c = try enc.encode(grade(replayed.events))
        XCTAssertEqual(a, b); XCTAssertEqual(a, c)
    }

    func testUnscoredMeasuresAreExcluded() {
        var s = score!
        s.unscoredMeasures = [3]
        let t = s.timeline(passage: s.wholePassage)
        let r = RhythmEvaluator.evaluate(timeline: t, hand: .both, events: play(t).filter { t.measureIndex(atUs: $0.timeUs) != 3 })
        XCTAssertEqual(r.missedCount, 0)
        XCTAssertTrue(r.evaluations.contains { $0.excludedReason == .unsupportedSpan })
        XCTAssertEqual(r.result, .inconclusive, "more than a tenth of the passage could not be graded")
    }
}

final class TechniqueAndCoachTests: XCTestCase {
    func testTimingSpreadIsMeasuredExactly() throws {
        // TH03: alternate +20 ms / -20 ms gives a spread of exactly 20 ms.
        let s = try tiny("C4:q D4 E4 F4 | G4 A4 B4 C5")
        let t = s.timeline(passage: s.wholePassage)
        var events = play(t, hand: .right)
        var k = 0
        for i in events.indices where events[i].type == .noteOn { events[i].timeUs += (k % 2 == 0) ? 20_000 : -20_000; k += 1 }
        events = renumber(events)
        let r = RhythmEvaluator.evaluate(timeline: t, hand: .right, events: events)
        let m = TechniqueMetrics.measure(timeline: t, report: r, events: events)
        XCTAssertEqual(m.timingSpreadMs ?? -1, 20, accuracy: 0.001)
        XCTAssertEqual(m.velocitySpread ?? -1, 0, accuracy: 0.001)
    }

    func testLegatoOverlapAndBalance() throws {
        // TH04 and TH06
        let s = try tiny("C4:q D4 E4 F4 | G4 A4 B4 C5 | D5 C5 B4 A4 | G4 F4 E4 D4", "C3:q E3 G3 E3 | C3 E3 G3 E3 | C3 E3 G3 E3 | C3 E3 G3 C3")
        let t = s.timeline(passage: s.wholePassage)
        var events: [PerformanceEvent] = []
        for a in t.attacks {
            events.append(PerformanceEvent(seq: 0, type: .noteOn, pitch: a.midi, velocity: a.hand == .right ? 60 : 90, timeUs: a.timeUs))
            events.append(PerformanceEvent(seq: 0, type: .noteOff, pitch: a.midi, timeUs: a.timeUs + a.durationUs + (a.hand == .right ? 30_000 : -50_000)))
        }
        events = renumber(events)
        let r = RhythmEvaluator.evaluate(timeline: t, hand: .both, events: events)
        XCTAssertEqual(r.result, .pass)
        let m = TechniqueMetrics.measure(timeline: t, report: r, events: events)
        XCTAssertEqual(m.handBalance ?? 0, -30, accuracy: 0.001, "accompaniment louder than the melody")
        XCTAssertEqual(m.legatoShare ?? 0, 0.5, accuracy: 0.05)
        XCTAssertEqual(m.handSyncMs ?? -1, 0, accuracy: 0.001)
        let rightOnly = RhythmEvaluator.evaluate(timeline: t, hand: .right, events: events)
        XCTAssertEqual(TechniqueMetrics.measure(timeline: t, report: rightOnly, events: events).legatoOverlapMs ?? 0, 30, accuracy: 0.001)
    }

    func testPedalTiming() {
        func pedal(_ t: Int64, _ v: Int) -> PerformanceEvent { PerformanceEvent(seq: t, type: .pedal, pedalValue: v, timeUs: t) }
        // Clean: lift at the change, press again just after.
        let clean = TechniqueMetrics.pedal(changeTimesUs: [2_000_000], events: [pedal(100_000, 127), pedal(2_020_000, 0), pedal(2_150_000, 127)])
        XCTAssertEqual(clean.cleanChanges, 1)
        // TH05 blurred: pedal never lifted.
        let blur = TechniqueMetrics.pedal(changeTimesUs: [2_000_000], events: [pedal(100_000, 127)])
        XCTAssertEqual(blur.blurredChanges, 1)
        // Early: back down before the new chord sounds.
        let early = TechniqueMetrics.pedal(changeTimesUs: [2_000_000], events: [pedal(100_000, 127), pedal(1_880_000, 0), pedal(1_950_000, 127)])
        XCTAssertEqual(early.earlyChanges, 1)
        // Half-pedal values below 64 count as up.
        let half = TechniqueMetrics.pedal(changeTimesUs: [2_000_000], events: [pedal(100_000, 127), pedal(2_010_000, 40), pedal(2_200_000, 90)])
        XCTAssertEqual(half.cleanChanges, 1)
    }

    func testCoachSuggestions() throws {
        let s = try tiny(twoHandPiece.rh, twoHandPiece.lh)
        let t = s.timeline(passage: s.wholePassage, tempoPercent: 60)
        var coach = Coach()
        let good = RhythmEvaluator.evaluate(timeline: t, hand: .both, events: play(t))
        XCTAssertEqual(coach.record(good, score: s, firstMeasure: 0, lastMeasure: 3, hand: .both, tempoPercent: 60).action, .repeatSame)
        let again = coach.record(good, score: s, firstMeasure: 0, lastMeasure: 3, hand: .both, tempoPercent: 60)
        XCTAssertEqual(again.action, .speedUp); XCTAssertEqual(again.tempoPercent, 65)

        let bad = RhythmEvaluator.evaluate(timeline: t, hand: .both, events: renumber(play(t).filter { t.measureIndex(atUs: $0.timeUs) != 2 }))
        let first = coach.record(bad, score: s, firstMeasure: 0, lastMeasure: 3, hand: .both, tempoPercent: 60)
        XCTAssertEqual(first.action, .repeatSame)
        XCTAssertTrue(first.message.contains("measure 3"), first.message)
        _ = coach.record(bad, score: s, firstMeasure: 0, lastMeasure: 3, hand: .both, tempoPercent: 60)
        let third = coach.record(bad, score: s, firstMeasure: 0, lastMeasure: 3, hand: .both, tempoPercent: 60)
        XCTAssertEqual(third.action, .shortenLoop); XCTAssertEqual(third.firstMeasure, 2)
    }

    func testLearningPathCoversThePiece() throws {
        let s = try tiny(Array(repeating: "C4:w", count: 9).joined(separator: " | "), Array(repeating: "C3:w", count: 9).joined(separator: " | "))
        XCTAssertEqual(LearningPath.autoPhrases(s), [0...3, 4...8])
        let steps = LearningPath.generate(score: s, troubleSpots: [2...3])
        XCTAssertEqual(steps.first?.kind, .listen); XCTAssertEqual(steps.last?.kind, .perform)
        XCTAssertEqual(Set(steps.map { $0.id }).count, steps.count)
        XCTAssertTrue(steps.contains { $0.kind == .join && $0.firstMeasure == 0 && $0.lastMeasure == 8 })
        XCTAssertTrue(steps.contains { $0.kind == .trouble })
        var p = SongProgress(songId: "x")
        XCTAssertEqual(p.nextStep(in: steps)?.id, "listen")
        p.completedSteps = ["listen"]
        XCTAssertEqual(p.nextStep(in: steps)?.id, "p0.rh")
    }
}
