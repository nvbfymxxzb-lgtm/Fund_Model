import XCTest
import Foundation
@testable import MusicModel
@testable import ScoreImport
@testable import PracticeEngine

func fixture(_ name: String) throws -> Data {
    let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(name)
    return try Data(contentsOf: url)
}

func tiny(_ rh: String, _ lh: String = "", time: String = "4/4", tempo: Int = 120, pickup: Bool = false,
          key: Int = 0, rh2: String? = nil) throws -> Score {
    let measures = rh.split(separator: "|").count
    let left = lh.isEmpty ? Array(repeating: "r:w", count: max(measures, 1)).joined(separator: " | ") : lh
    return try TinyNotation.parse(SongSource(title: "Test", keyFifths: key, time: time, tempo: tempo, pickup: pickup, rh: rh, lh: left, rh2: rh2))
}

/// A perfect performance of a passage, as events.
func play(_ timeline: PassageTimeline, hand: HandSelection = .both, velocity: Int = 80, legato: Bool = true) -> [PerformanceEvent] {
    var events: [PerformanceEvent] = []
    for a in timeline.attacks(for: hand) {
        events.append(PerformanceEvent(seq: 0, type: .noteOn, pitch: a.midi, velocity: velocity, timeUs: a.timeUs))
        events.append(PerformanceEvent(seq: 0, type: .noteOff, pitch: a.midi, velocity: 0, timeUs: a.timeUs + (legato ? a.durationUs - 1000 : a.durationUs / 2)))
    }
    return renumber(events)
}

func renumber(_ events: [PerformanceEvent]) -> [PerformanceEvent] {
    let sorted = events.enumerated().sorted { ($0.element.timeUs, $0.offset) < ($1.element.timeUs, $1.offset) }.map { $0.element }
    return sorted.enumerated().map { var e = $0.element; e.seq = Int64($0.offset + 1); return e }
}

let twoHandPiece = (rh: "C4:q D4 E4 F4 | G4 A4 B4 C5 | C5 B4 A4 G4 | F4 E4 D4 C4",
                    lh: "[C3 G3]:h [C3 G3] | [C3 E3]:h [F3 A3] | [C3 E3]:h [F3 A3] | [G2 G3]:h C3")
