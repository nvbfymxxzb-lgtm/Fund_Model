import XCTest
import Foundation
@testable import MusicModel
@testable import ScoreImport
@testable import PracticeEngine
@testable import Difficulty
@testable import TheoryKit
@testable import Curriculum

final class TheoryTests: XCTestCase {
    func names(_ t: String, _ type: ScaleType) -> String { Theory.scale(NoteName(t)!, type).prefix(7).map { $0.ascii }.joined(separator: " ") }

    func testMajorScalesAreSpelledCorrectly() {
        // TH08: checked by hand against the circle of fifths.
        let expected: [String: String] = [
            "C": "C D E F G A B", "G": "G A B C D E F#", "D": "D E F# G A B C#", "A": "A B C# D E F# G#",
            "E": "E F# G# A B C# D#", "B": "B C# D# E F# G# A#", "F#": "F# G# A# B C# D# E#", "C#": "C# D# E# F# G# A# B#",
            "F": "F G A Bb C D E", "Bb": "Bb C D Eb F G A", "Eb": "Eb F G Ab Bb C D", "Ab": "Ab Bb C Db Eb F G",
            "Db": "Db Eb F Gb Ab Bb C", "Gb": "Gb Ab Bb Cb Db Eb F", "Cb": "Cb Db Eb Fb Gb Ab Bb",
        ]
        for (tonic, scale) in expected { XCTAssertEqual(names(tonic, .major), scale, tonic) }
    }

    func testMinorScales() {
        XCTAssertEqual(names("A", .naturalMinor), "A B C D E F G")
        XCTAssertEqual(names("A", .harmonicMinor), "A B C D E F G#")
        XCTAssertEqual(names("A", .melodicMinor), "A B C D E F# G#")
        XCTAssertEqual(names("C", .harmonicMinor), "C D Eb F G Ab B")
        XCTAssertEqual(names("F#", .naturalMinor), "F# G# A B C# D E")
        XCTAssertEqual(names("Bb", .naturalMinor), "Bb C Db Eb F Gb Ab")
        XCTAssertEqual(names("G#", .harmonicMinor), "G# A# B C# D# E F##")
    }

    func testKeySignatures() {
        let major: [String: Int] = ["C": 0, "G": 1, "D": 2, "A": 3, "E": 4, "B": 5, "F#": 6, "F": -1, "Bb": -2, "Eb": -3, "Ab": -4, "Db": -5, "Gb": -6]
        for (k, f) in major {
            XCTAssertEqual(Theory.fifths(majorTonic: NoteName(k)!), f, k)
            XCTAssertEqual(Theory.majorTonic(fifths: f).ascii, k)
            // The signature must be exactly the altered notes of the scale.
            let altered = Set(Theory.scale(NoteName(k)!, .major).filter { $0.alter != 0 })
            XCTAssertEqual(Set(Theory.signature(fifths: f)), altered, k)
        }
        XCTAssertEqual(Theory.fifths(minorTonic: NoteName("A")!), 0)
        XCTAssertEqual(Theory.fifths(minorTonic: NoteName("E")!), 1)
        XCTAssertEqual(Theory.fifths(minorTonic: NoteName("D")!), -1)
        XCTAssertEqual(Theory.fifths(minorTonic: NoteName("F#")!), 3)
        XCTAssertEqual(Theory.keyName(fifths: -3, minor: true), "C minor")
        XCTAssertEqual(Theory.signature(fifths: 2).map { $0.ascii }, ["F#", "C#"])
        XCTAssertEqual(Theory.signature(fifths: -2).map { $0.ascii }, ["Bb", "Eb"])
    }

    func testChordSpelling() {
        func tones(_ r: String, _ q: ChordQuality) -> String { ChordSpec(root: r, quality: q).tones.map { $0.ascii }.joined(separator: " ") }
        XCTAssertEqual(tones("C", .major), "C E G")
        XCTAssertEqual(tones("D", .minor), "D F A")
        XCTAssertEqual(tones("B", .diminished), "B D F")
        XCTAssertEqual(tones("C", .augmented), "C E G#")
        XCTAssertEqual(tones("G", .dominant7), "G B D F")
        XCTAssertEqual(tones("C", .major7), "C E G B")
        XCTAssertEqual(tones("D", .minor7), "D F A C")
        XCTAssertEqual(tones("B", .halfDiminished7), "B D F A")
        XCTAssertEqual(tones("B", .diminished7), "B D F Ab")
        XCTAssertEqual(tones("Bb", .minor), "Bb Db F")
        XCTAssertEqual(tones("F#", .major), "F# A# C#")
        XCTAssertEqual(tones("Eb", .dominant7), "Eb G Bb Db")
        XCTAssertEqual(ChordSpec(root: "C", quality: .major, inversion: 1).symbol, "C/E")
        XCTAssertEqual(ChordSpec(root: "C", quality: .major, inversion: 1).pitches(above: 60).map { $0.midi }, [64, 67, 72])
        XCTAssertEqual(ChordSpec(root: "G", quality: .major, inversion: 2).pitches(above: 60).map { $0.midi }, [62, 67, 71])
    }

    func testDiatonicChordsAndRomanNumerals() {
        let c = (1...7).map { Theory.diatonicTriad(degree: $0, tonic: NoteName("C")!, minor: false) }
        XCTAssertEqual(c.map { $0.symbol }, ["C", "Dm", "Em", "F", "G", "Am", "Bdim"])
        XCTAssertEqual(c.enumerated().map { Theory.roman(degree: $0.offset + 1, quality: $0.element.quality) }, ["I", "ii", "iii", "IV", "V", "vi", "vii°"])
        let a = (1...7).map { Theory.diatonicTriad(degree: $0, tonic: NoteName("A")!, minor: true) }
        XCTAssertEqual(a.map { $0.symbol }, ["Am", "Bdim", "Caug", "Dm", "E", "F", "G♯dim"])
        XCTAssertEqual(Theory.diatonicTriad(degree: 5, tonic: NoteName("Bb")!, minor: false).symbol, "F")
    }

    func testIntervalNames() {
        func name(_ a: String, _ b: String) -> String { Theory.intervalName(from: SpelledPitch(a)!, to: SpelledPitch(b)!) }
        XCTAssertEqual(name("C4", "E4"), "major third")
        XCTAssertEqual(name("C4", "Eb4"), "minor third")
        XCTAssertEqual(name("C4", "G4"), "perfect fifth")
        XCTAssertEqual(name("C4", "F#4"), "augmented fourth")
        XCTAssertEqual(name("C4", "Gb4"), "diminished fifth")
        XCTAssertEqual(name("E4", "C5"), "minor sixth")
        XCTAssertEqual(name("C4", "C5"), "perfect octave")
        XCTAssertEqual(name("B3", "C4"), "minor second")
    }

    func testChordChecker() {
        let c1 = ChordSpec(root: "E", quality: .minor, inversion: 1)
        XCTAssertEqual(ExerciseChecker.chord(held: [52, 55, 59], spec: c1, requireInversion: true), .wrongInversion(expectedBass: "G"), "TH01")
        XCTAssertEqual(ExerciseChecker.chord(held: [55, 59, 64], spec: c1, requireInversion: true), .correct)
        XCTAssertEqual(ExerciseChecker.chord(held: [52, 55, 59], spec: c1, requireInversion: false), .correct)
        XCTAssertEqual(ExerciseChecker.chord(held: [52, 55, 59, 60], spec: c1, requireInversion: false), .wrongNotes(extra: [60]), "TH02")
        XCTAssertEqual(ExerciseChecker.chord(held: [52, 59], spec: c1, requireInversion: false), .incomplete(missing: ["G"]))
        XCTAssertEqual(ExerciseChecker.chord(held: [40, 55, 59, 64, 67], spec: c1, requireInversion: false), .correct, "any octave, doubling allowed")
        XCTAssertEqual(ExerciseChecker.chord(held: [], spec: c1, requireInversion: false), .nothing)
        XCTAssertEqual(ExerciseChecker.interval(held: [62, 69], rootMidi: 62, semitones: 7), .correct)
        XCTAssertEqual(ExerciseChecker.interval(held: [69], rootMidi: 62, semitones: 7), .correct)
        XCTAssertEqual(ExerciseChecker.interval(held: [68], rootMidi: 62, semitones: 7), .wrongNotes(extra: [68]))
    }

    func testScaleScores() throws {
        let c = TheoryScores.scale(tonic: NoteName("C")!, type: .major, hand: .right)
        XCTAssertEqual(c.measures.count, 4)
        let rh = c.notes.filter { $0.hand == .right }
        XCTAssertEqual(rh.map { $0.midi }, [60, 62, 64, 65, 67, 69, 71, 72, 71, 69, 67, 65, 64, 62, 60])
        XCTAssertEqual(rh.prefix(8).map { $0.finger }, [1, 2, 3, 1, 2, 3, 4, 5])
        XCTAssertTrue(c.notes.filter { $0.hand == .left }.isEmpty)
        let f = TheoryScores.scale(tonic: NoteName("F")!, type: .major, hand: .both)
        XCTAssertEqual(f.notes.filter { $0.hand == .right }.prefix(8).map { $0.pitch.description }, ["F4", "G4", "A4", "B♭4", "C5", "D5", "E5", "F5"])
        XCTAssertEqual(f.notes.filter { $0.hand == .left }.prefix(8).map { $0.finger }, [5, 4, 3, 2, 1, 3, 2, 1])
        XCTAssertEqual(f.measures[0].keyFifths, -1)
        let m = TheoryScores.scale(tonic: NoteName("A")!, type: .melodicMinor, hand: .right)
        XCTAssertEqual(m.notes.map { $0.midi }, [69, 71, 72, 74, 76, 78, 80, 81, 79, 77, 76, 74, 72, 71, 69], "melodic minor comes down as natural minor")
        let two = TheoryScores.scale(tonic: NoteName("G")!, type: .major, hand: .right, octaves: 2)
        XCTAssertEqual(two.notes.count, 29); XCTAssertEqual(two.measures.count, 8)
        let chords = TheoryScores.chords([ChordSpec(root: "C"), ChordSpec(root: "F", quality: .major, inversion: 2)])
        XCTAssertEqual(chords.measures.count, 2)
        // Every generated score must survive being written and read back.
        for s in [c, f, m, two, chords] { XCTAssertNoThrow(try ScoreImporter.importXML(Data(MusicXMLWriter.write(s).utf8))) }
    }

    func testGeneratorsAreRepeatableAndValid() {
        // TH09
        for kind in [GeneratorSpec.Kind.chordPlay, .chordSpell, .keySignature, .intervalName, .intervalPlay, .earInterval, .earChord, .romanPlay, .romanName, .scaleNotes] {
            let spec = GeneratorSpec(kind: kind, count: 8, inversions: kind == .chordPlay)
            let a = ExerciseGenerator.make(spec, seed: 42), b = ExerciseGenerator.make(spec, seed: 42), c = ExerciseGenerator.make(spec, seed: 43)
            XCTAssertEqual(a, b, "\(kind)")
            XCTAssertNotEqual(a, c, "\(kind)")
            XCTAssertEqual(a.count, 8, "\(kind)")
            for e in a {
                XCTAssertTrue(ContentPack.check(e).isEmpty, "\(kind): \(ContentPack.check(e))")
                if let options = e.options, let answer = e.answer {
                    XCTAssertEqual(Set(options).count, options.count, "\(e.prompt) \(options)")
                    XCTAssertTrue((2...4).contains(options.count))
                    XCTAssertTrue(e.explanation?.contains(options[answer]) ?? false, "the explanation should state the answer: \(e.prompt) / \(options[answer]) / \(e.explanation ?? "")")
                }
            }
        }
    }
}

final class ContentTests: XCTestCase {
    static let pack = ContentPack.loadBundled()
    var pack: ContentPack { ContentTests.pack }

    func testPackLoadsWithoutProblems() {
        XCTAssertTrue(pack.problems.isEmpty, pack.problems.map { $0.description }.joined(separator: "\n"))
        XCTAssertEqual(pack.songs.count, 11)
        XCTAssertGreaterThanOrEqual(pack.lessons.count, 18)
        XCTAssertFalse(pack.units(in: .pianoTechnique).isEmpty)
        XCTAssertFalse(pack.units(in: .musicTheory).isEmpty)
    }

    func testSongsAreRankedAndPlayable() throws {
        XCTAssertEqual(pack.songs.map { $0.level }, pack.songs.map { $0.level }.sorted())
        for song in pack.songs {
            XCTAssertFalse(song.score.notes.isEmpty, song.id)
            XCTAssertFalse(song.steps.isEmpty, song.id)
            XCTAssertFalse(song.difficulty.topReasons.isEmpty, song.id)
            // Both hands have something to play and stay in a sensible range.
            XCTAssertTrue(song.score.notes.contains { $0.hand == .left }, song.id)
            XCTAssertTrue(song.score.notes.allSatisfy { (33...96).contains($0.midi) }, song.id)
            // No hand is asked to stretch beyond a ninth at once.
            for (_, group) in Dictionary(grouping: song.score.notes, by: { "\($0.measureIndex)|\($0.onset)|\($0.hand)|\($0.voice)" }) {
                let span = (group.map { $0.midi }.max() ?? 0) - (group.map { $0.midi }.min() ?? 0)
                XCTAssertLessThanOrEqual(span, 14, "\(song.id) m\(group[0].measureIndex)")
            }
            // A perfect performance passes, in both modes, and the display file reads back to the same notes.
            let t = song.score.timeline(passage: song.score.wholePassage)
            let events = play(t)
            XCTAssertEqual(RhythmEvaluator.evaluate(timeline: t, hand: .both, events: events).result, .pass, song.id)
            var wait = WaitModeSession(timeline: t, hand: .both)
            for e in events { _ = wait.handle(e) }
            XCTAssertTrue(wait.isFinished, song.id); XCTAssertEqual(wait.report().result, .pass, song.id)
            let back = try ScoreImporter.importXML(Data(song.displayXML.utf8)).score
            XCTAssertEqual(back.notes.map { $0.matchKey }.sorted(), song.score.notes.map { $0.matchKey }.sorted(), song.id)
            XCTAssertTrue(back.warnings.isEmpty, "\(song.id): \(back.warnings)")
            // Every step covers real measures.
            for step in song.steps {
                XCTAssertTrue(song.score.measures.indices.contains(step.firstMeasure) && song.score.measures.indices.contains(step.lastMeasure), "\(song.id) \(step.id)")
                let p = song.score.passage(measures: step.firstMeasure, step.lastMeasure)
                XCTAssertFalse(song.score.timeline(passage: p, tempoPercent: step.tempoPercent).attacks.isEmpty, "\(song.id) \(step.id)")
            }
        }
    }

    func testComputedDifficultyAgreesWithLevels() {
        // The measured difficulty should rise with the assigned level (rank correlation).
        let songs = pack.songs
        for s in songs { print(String(format: "L%d  %5.1f  est L%d  %@  — %@", s.level, s.difficulty.score, s.difficulty.estimatedLevel, s.id, s.difficulty.topReasons.joined(separator: "; "))) }
        func ranks(_ v: [Double]) -> [Double] {
            let sorted = v.enumerated().sorted { $0.element < $1.element }
            var r = [Double](repeating: 0, count: v.count)
            var i = 0
            while i < sorted.count {
                var j = i
                while j + 1 < sorted.count && sorted[j + 1].element == sorted[i].element { j += 1 }
                for k in i...j { r[sorted[k].offset] = Double(i + j) / 2 + 1 }
                i = j + 1
            }
            return r
        }
        let a = ranks(songs.map { Double($0.level) }), b = ranks(songs.map { $0.difficulty.score })
        let ma = a.reduce(0, +) / Double(a.count), mb = b.reduce(0, +) / Double(b.count)
        let cov = zip(a, b).map { ($0 - ma) * ($1 - mb) }.reduce(0, +)
        let rho = cov / (a.map { ($0 - ma) * ($0 - ma) }.reduce(0, +) * b.map { ($0 - mb) * ($0 - mb) }.reduce(0, +)).squareRoot()
        print("Spearman rho between assigned level and computed difficulty:", rho)
        XCTAssertGreaterThan(rho, 0.75)
        for s in songs { XCTAssertLessThanOrEqual(abs(s.difficulty.estimatedLevel - s.level), 1, "\(s.id): estimated \(s.difficulty.estimatedLevel), assigned \(s.level)") }
    }

    func testLessonsLinkToSongsAndSkills() {
        for lesson in pack.lessons {
            XCTAssertFalse(lesson.blocks.isEmpty, lesson.id)
            XCTAssertTrue(lesson.blocks.contains { $0.type == .exercise || $0.type == .generated || $0.type == .checklist }, "\(lesson.id) has nothing to do")
        }
        let ode = pack.songs.first { $0.id == "ode-to-joy" }!
        XCTAssertTrue(pack.lessons(for: ode).contains { $0.id == "p3.3" })
        XCTAssertTrue(pack.songs(for: pack.lesson("m1.2")!).contains { $0.id == "greensleeves" })
        // Every skill is taught by a lesson or used by a song.
        for skill in pack.skills {
            XCTAssertTrue(pack.lessons.contains { $0.skillIds.contains(skill.id) } || pack.songs.contains { $0.skillIds.contains(skill.id) }, skill.id)
        }
    }

    func testProgressStoreRoundTripAndReview() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("piano-test-\(UUID().uuidString)/progress.json")
        var p = AppProgress()
        p.songs["ode-to-joy"] = SongProgress(songId: "ode-to-joy")
        p.songs["ode-to-joy"]?.completedSteps = ["listen", "p0.rh"]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        p.record(skills: ["m.triads"], success: true, now: now)
        p.record(skills: ["m.triads"], success: true, now: now)
        XCTAssertEqual(p.skills["m.triads"]?.box, 2)
        XCTAssertEqual(p.skills["m.triads"]?.nextReview, now.addingTimeInterval(3 * 86_400))
        p.record(skills: ["m.triads"], success: false, now: now)
        XCTAssertEqual(p.skills["m.triads"]?.box, 1)
        XCTAssertTrue(p.skills["m.triads"]!.isDue(now: now.addingTimeInterval(2 * 86_400)))
        try ProgressStore.save(p, to: url)
        XCTAssertEqual(ProgressStore.load(from: url), p)
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(ProgressStore.load(from: url), AppProgress(), "a damaged file never crashes the app")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("unreadable").path), "and is kept aside, not lost")
    }

    func testImportedSongsAreStoredAndRated() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("piano-import-\(UUID().uuidString)")
        let store = ImportedSongStore(folder: folder)
        let entry = try store.add(data: try fixture("zipped.mxl"), filename: "/some/private/path/zipped.mxl")
        XCTAssertEqual(entry.origin, .imported); XCTAssertTrue(entry.levelIsEstimated)
        XCTAssertFalse(entry.about.contains("private"))
        let all = store.loadAll()
        XCTAssertEqual(all.count, 1); XCTAssertEqual(all[0].id, entry.id); XCTAssertEqual(all[0].score.notes.count, 4)
        store.delete(id: entry.id)
        XCTAssertTrue(store.loadAll().isEmpty)
    }
}
