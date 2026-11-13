import XCTest
import Foundation
@testable import MusicModel
@testable import ScoreImport
@testable import PracticeEngine

final class MusicModelTests: XCTestCase {
    func testRational() {
        XCTAssertEqual(Rational(2, 4), Rational(1, 2))
        XCTAssertEqual(Rational(1, 4) + Rational(1, 12), Rational(1, 3))
        XCTAssertEqual(Rational(1, 3) * Rational(3, 1), Rational(1, 1))
        XCTAssertTrue(Rational(1, 3) < Rational(1, 2))
        XCTAssertEqual(Rational(5, 2).rounded, 2)   // half to even
        XCTAssertEqual(Rational(7, 2).rounded, 4)
        XCTAssertEqual(Rational(-1, -2), Rational(1, 2))
    }

    func testPitch() {
        XCTAssertEqual(SpelledPitch("C4")?.midi, 60)
        XCTAssertEqual(SpelledPitch("F#5")?.midi, 78)
        XCTAssertEqual(SpelledPitch("Bb3")?.midi, 58)
        XCTAssertEqual(SpelledPitch("Cb4")?.midi, 59)
        XCTAssertEqual(SpelledPitch("A0")?.midi, 21)
        XCTAssertNil(SpelledPitch("H4"))
        XCTAssertEqual(SpelledPitch.from(midi: 61).description, "C♯4")
        XCTAssertEqual(SpelledPitch.from(midi: 61, preferFlats: true).description, "D♭4")
    }

    func testTinyNotationBasics() throws {
        let s = try tiny("C4:q D4 E4 F4 | [C4 E4 G4]:h r:q G4:q", "C3:w | C3:h. r:q")
        XCTAssertEqual(s.measures.count, 2)
        XCTAssertEqual(s.notes.filter { $0.hand == .right }.count, 8)
        XCTAssertEqual(s.notes.first { $0.measureIndex == 1 && $0.midi == 67 && $0.hand == .right && $0.onset == Rational(3, 4) }?.duration, Rational(1, 4))
        XCTAssertEqual(s.measures[0].length, Rational(1, 1))
    }

    func testTinyNotationRejectsWrongMeasureLength() {
        XCTAssertThrowsError(try tiny("C4:q D4 E4 | C4:w"))
        XCTAssertThrowsError(try tiny("C4:q D4 E4 X4"))
        XCTAssertThrowsError(try tiny("C4:w | C4:w", "C3:w"))
    }

    func testTiesAndFreshAttacks() throws {
        let s = try tiny("C4:q C4 C4 C4:q~ | C4:h r:h")
        let cs = s.notes.filter { $0.hand == .right }
        XCTAssertEqual(cs.map { $0.tie }, [nil, nil, nil, .start, .stop])
        let t = s.timeline(passage: s.wholePassage)
        let attacks = t.attacks(for: .right)
        XCTAssertEqual(attacks.count, 4, "the tied continuation is not struck again")
        XCTAssertEqual(attacks.last?.durationUs, 1_500_000, "tied note sounds for a quarter plus a half at 120 bpm")
    }

    func testPickupAndTriplets() throws {
        let s = try tiny("G4:q | C5:et D5 E5 C5:et D5 E5 C5:h | C5:h.", "r:q | C3:w | C3:h.", pickup: true)
        XCTAssertTrue(s.measures[0].isPickup)
        XCTAssertEqual(s.measures[0].number, "0")
        XCTAssertEqual(s.notes.filter { $0.measureIndex == 1 && $0.hand == .right }.map { $0.onset },
                       [Rational(0, 1), Rational(1, 12), Rational(1, 6), Rational(1, 4), Rational(1, 3), Rational(5, 12), Rational(1, 2)])
    }

    func testTimelineTiming() throws {
        let s = try tiny("C4:q D4 E4 F4 | G4:w")
        let t = s.timeline(passage: s.wholePassage)
        XCTAssertEqual(t.attacks(for: .right).map { $0.timeUs }, [0, 500_000, 1_000_000, 1_500_000, 2_000_000])
        XCTAssertEqual(t.totalUs, 4_000_000)
        XCTAssertEqual(t.beatTimesUs.count, 8)
        let slow = s.timeline(passage: s.wholePassage, tempoPercent: 50)
        XCTAssertEqual(slow.attacks(for: .right)[1].timeUs, 1_000_000)
        let second = s.timeline(passage: s.passage(measures: 1, 1))
        XCTAssertEqual(second.attacks(for: .right).map { $0.timeUs }, [0])
    }

    func testRepeatsExpand() throws {
        let s = try tiny("|: C4:w | D4:w :| E4:w")
        XCTAssertEqual(s.playbackOrder().map { $0.measureIndex }, [0, 1, 0, 1, 2])
        let t = s.timeline(passage: s.wholePassage)
        XCTAssertEqual(t.attacks.map { $0.midi }, [60, 62, 60, 62, 64])
        XCTAssertEqual(Set(t.attacks.map { $0.id }).count, 5, "each time through gets its own id")
    }

    func testWriterImporterRoundTrip() throws {
        let s = try tiny("G4:q | C5:et D5 E5 F#5:q. G5:e A5:q~ | A5:h [C5 E5]:q r:q | C5:h.",
                         "r:q | [C3 E3 G3]:h Bb2:q. C3:e | F2:w | C3:h.", pickup: true, key: 1, rh2: "- | E4:w | C4:h r:h | E4:h.")
        let xml = MusicXMLWriter.write(s)
        let back = try ScoreImporter.importXML(Data(xml.utf8)).score
        func shape(_ score: Score) -> [String] {
            score.notes.map { "\($0.measureIndex)|\($0.staff)|\($0.midi)|\($0.onset)|\($0.duration)|\($0.tie?.rawValue ?? "-")|\($0.pitch.alter)" }.sorted()
        }
        XCTAssertEqual(shape(back), shape(s))
        XCTAssertEqual(back.measures.map { $0.length }, s.measures.map { $0.length })
        XCTAssertTrue(back.measures[0].isPickup)
        XCTAssertEqual(back.measures[0].keyFifths, 1)
        XCTAssertEqual(back.baseTempo, 120)
        XCTAssertTrue(back.warnings.isEmpty, "\(back.warnings)")
    }
}

final class ImportTests: XCTestCase {
    func wrap(_ measures: String) -> Data {
        Data("""
        <?xml version="1.0"?><score-partwise><part-list><score-part id="P1"><part-name>P</part-name></score-part></part-list>
        <part id="P1">\(measures)</part></score-partwise>
        """.utf8)
    }
    func note(_ step: String, _ octave: Int, _ dur: Int, extra: String = "", voice: Int = 1, staff: Int = 1) -> String {
        "<note>\(extra)<pitch><step>\(step)</step><octave>\(octave)</octave></pitch><duration>\(dur)</duration><voice>\(voice)</voice><staff>\(staff)</staff></note>"
    }
    let attrs = "<attributes><divisions>2</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><staves>2</staves></attributes>"

    func testVoicesWithBackupAreNotPlayedInSequence() throws {
        let m = "<measure number=\"1\">\(attrs)\(note("E", 5, 8))<backup><duration>8</duration></backup>\(note("C", 4, 4, voice: 2))\(note("D", 4, 4, voice: 2))<backup><duration>8</duration></backup>\(note("C", 3, 8, voice: 5, staff: 2))</measure>"
        let s = try ScoreImporter.importXML(wrap(m)).score
        XCTAssertEqual(s.measures[0].length, Rational(1, 1))
        XCTAssertEqual(s.notes.map { "\($0.midi)@\($0.onset)" }.sorted(), ["48@0", "60@0", "62@1/2", "76@0"])
        XCTAssertEqual(s.notes.first { $0.midi == 48 }?.hand, .left)
        XCTAssertEqual(Set(s.notes.filter { $0.staff == 1 }.map { $0.voice }), [1, 2])
    }

    func testEndingsAndRepeats() throws {
        func bar(_ n: Int, _ step: String, _ extra: String = "") -> String { "<measure number=\"\(n)\">\(n == 1 ? attrs : "")\(extra)\(note(step, 4, 8))</measure>" }
        let xml = bar(1, "C", "<barline location=\"left\"><repeat direction=\"forward\"/></barline>")
            + "<measure number=\"2\"><barline location=\"left\"><ending number=\"1\" type=\"start\"/></barline>\(note("D", 4, 8))<barline location=\"right\"><ending number=\"1\" type=\"stop\"/><repeat direction=\"backward\"/></barline></measure>"
            + "<measure number=\"3\"><barline location=\"left\"><ending number=\"2\" type=\"start\"/></barline>\(note("E", 4, 8))<barline location=\"right\"><ending number=\"2\" type=\"discontinue\"/></barline></measure>"
            + bar(4, "F")
        let s = try ScoreImporter.importXML(wrap(xml)).score
        XCTAssertEqual(s.playbackOrder().map { $0.measureIndex }, [0, 1, 0, 2, 3])
    }

    func testChordsTiesTempoAndPickup() throws {
        let m0 = "<measure number=\"0\" implicit=\"yes\">\(attrs)<direction><sound tempo=\"90\"/></direction>\(note("G", 4, 2))</measure>"
        let m1 = "<measure number=\"1\">\(note("C", 4, 4, extra: "<tie type=\"start\"/>"))\(note("E", 4, 4, extra: "<chord/>"))\(note("C", 4, 4, extra: "<tie type=\"stop\"/>"))</measure>"
        let s = try ScoreImporter.importXML(wrap(m0 + m1)).score
        XCTAssertTrue(s.measures[0].isPickup)
        XCTAssertEqual(s.measures[0].length, Rational(1, 4))
        XCTAssertEqual(s.baseTempo, 90)
        XCTAssertEqual(s.notes.filter { $0.measureIndex == 1 }.map { $0.onset }, [.zero, .zero, Rational(1, 2)])
        XCTAssertEqual(s.timeline(passage: s.wholePassage).attacks.count, 3)
    }

    func testUnsupportedNotationWarnsAndIsNotGraded() throws {
        let m1 = "<measure number=\"1\">\(attrs)<note><grace/><pitch><step>D</step><octave>5</octave></pitch><voice>1</voice></note>\(note("C", 5, 8))</measure>"
        let m2 = "<measure number=\"2\"><direction><direction-type><octave-shift type=\"down\" size=\"8\"/></direction-type></direction>\(note("C", 6, 8))</measure>"
        let m3 = "<measure number=\"3\"><direction><direction-type><octave-shift type=\"stop\"/></direction-type></direction>\(note("C", 5, 8, extra: ""))</measure>"
        let m4 = "<measure number=\"4\"><direction><sound dacapo=\"yes\"/></direction>\(note("C", 5, 8))</measure>"
        let s = try ScoreImporter.importXML(wrap(m1 + m2 + m3 + m4)).score
        XCTAssertEqual(Set(s.warnings.map { $0.code }), ["grace", "octaveShift", "jumps", "noTempo"])
        XCTAssertEqual(s.unscoredMeasures, [0, 1])
        let t = s.timeline(passage: s.wholePassage)
        XCTAssertEqual(t.attacks.filter { $0.unscored }.count, 2)
        XCTAssertEqual(t.attacks.count, 4, "grace notes are never expected attacks")
    }

    func testCompressedFiles() throws {
        let r = try ScoreImporter.importFile(data: try fixture("zipped.mxl"), filename: "zipped.mxl")
        XCTAssertEqual(r.score.title, "Zipped")
        XCTAssertEqual(r.score.notes.map { $0.midi }, [60, 62, 64, 65])
        let big = try ScoreImporter.importFile(data: try fixture("big.mxl"), filename: "big.mxl")
        XCTAssertEqual(big.score.measures.count, 399)
        XCTAssertEqual(big.score.notes.count, 4 * 399)
    }

    func testHostileInputsAreRejected() throws {
        XCTAssertThrowsError(try ScoreImporter.importFile(data: try fixture("traversal.mxl"), filename: "t.mxl")) {
            XCTAssertEqual($0 as? ScoreImportError, .archive("unsafe path in archive"))
        }
        let xxe = "<?xml version=\"1.0\"?><!DOCTYPE x [<!ENTITY xxe SYSTEM \"file:///etc/passwd\">]><score-partwise><part id=\"P1\"/></score-partwise>"
        XCTAssertThrowsError(try ScoreImporter.importXML(Data(xxe.utf8))) {
            XCTAssertEqual($0 as? ScoreImportError, .unsafeContent("it declares XML entities"))
        }
        XCTAssertThrowsError(try ScoreImporter.importXML(Data("<score-timewise><measure/></score-timewise>".utf8))) {
            XCTAssertEqual($0 as? ScoreImportError, .timewise)
        }
        XCTAssertThrowsError(try ScoreImporter.importXML(Data("hello".utf8)))
        XCTAssertThrowsError(try ScoreImporter.importXML(Data(count: ScoreImporter.maxBytes + 1))) {
            XCTAssertEqual($0 as? ScoreImportError, .tooLarge)
        }
        XCTAssertThrowsError(try ScoreImporter.importFile(data: Data([0x50, 0x4b, 1, 2, 3, 4, 5, 6]), filename: "x.mxl"))
    }
}

final class MIDITests: XCTestCase {
    func testDecoder() {
        XCTAssertEqual(MIDIDecoder.decode(status: 0x90, data1: 60, data2: 100)?.type, .noteOn)
        XCTAssertEqual(MIDIDecoder.decode(status: 0x90, data1: 60, data2: 0)?.type, .noteOff, "note-on with velocity 0 is a note-off")
        XCTAssertEqual(MIDIDecoder.decode(status: 0x83, data1: 60, data2: 40)?.channel, 4)
        XCTAssertEqual(MIDIDecoder.decode(status: 0xB0, data1: 64, data2: 127)?.pedalValue, 127)
        XCTAssertEqual(MIDIDecoder.decode(status: 0xB0, data1: 123, data2: 0)?.type, .allNotesOff)
        XCTAssertNil(MIDIDecoder.decode(status: 0xB0, data1: 7, data2: 100))
        XCTAssertNil(MIDIDecoder.decode(status: 0xE0, data1: 0, data2: 64))
        XCTAssertEqual(MIDIDecoder.decode(umpWord: 0x2090_3C64)?.pitch, 60)
        XCTAssertNil(MIDIDecoder.decode(umpWord: 0x1090_3C64))
    }

    func testActiveNotesClearOnDisconnect() {
        var a = ActiveNotes()
        a.apply(.noteOn(60, at: 0)); a.apply(PerformanceEvent(seq: 1, type: .pedal, pedalValue: 100, timeUs: 1))
        XCTAssertEqual(a.held, [60]); XCTAssertTrue(a.pedalDown)
        a.apply(PerformanceEvent(seq: 2, type: .disconnect, timeUs: 2))
        XCTAssertTrue(a.held.isEmpty); XCTAssertFalse(a.pedalDown)
    }

    func testTraceRoundTrip() throws {
        let s = try tiny("C4:q D4 E4 F4")
        let t = s.timeline(passage: s.wholePassage)
        let trace = PerformanceTrace(header: TraceHeader(songId: "x", passage: t.passage, hand: .both, mode: .rhythm, tempoPercent: 100), events: play(t))
        let text = try trace.jsonLines()
        XCTAssertEqual(try PerformanceTrace(jsonLines: text), trace)
        XCTAssertEqual(try PerformanceTrace(jsonLines: text).jsonLines(), text)
    }
}
