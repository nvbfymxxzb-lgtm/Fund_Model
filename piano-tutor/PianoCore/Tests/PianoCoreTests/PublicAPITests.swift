import XCTest
import Foundation
import PianoCore   // deliberately not @testable: this file sees only what the iPad app sees

/// Uses the core the same way the app does, so a missing `public` breaks this test instead of the app build.
final class PublicAPITests: XCTestCase {
    func testAppUsage() throws {
        let pack = ContentPack.loadBundled()
        let song = try XCTUnwrap(pack.songs.first)
        _ = ContentPack.ranked(pack.songs)
        _ = (song.title, song.composer, song.level, song.levelIsEstimated, song.about, song.skillIds, song.reviewState, song.origin, song.displayXML)
        _ = (song.difficulty.topReasons, song.difficulty.score, song.score.warnings.first?.message, song.score.baseTempo, song.score.measures.first?.number)
        _ = (pack.lessons(for: song), pack.units(in: .musicTheory), pack.skill("m.triads")?.title, pack.lesson("m1.1")?.blocks.first?.type)
        let lesson = try XCTUnwrap(pack.lessons.first)
        _ = pack.songs(for: lesson)
        _ = Track.allCases.map { $0.title }

        var progress = AppProgress()
        var sp = SongProgress(songId: song.id)
        sp.completedSteps.insert(song.steps[0].id); sp.userRating = 3; sp.lastPracticed = Date(); sp.attempts += 1
        _ = (sp.fraction(of: song.steps), sp.nextStep(in: song.steps)?.title, sp.bestFullTempoPercent)
        progress.songs[song.id] = sp
        progress.lessons[lesson.id] = LessonProgress()
        progress.record(skills: ["m.triads"], success: true)
        _ = progress.skills["m.triads"]?.isDue()
        _ = progress.skills["m.triads"]?.isSecure
        progress.settings.strictChords = false
        progress.settings.calibrationOffsetMs = 10
        _ = (progress.settings.demoThroughPiano, progress.settings.metronomeOn, progress.settings.showNoteNames, progress.settings.accompanyOtherHand, progress.settings.keyTouchNote)

        var tolerances = Tolerances(); tolerances.strictChords = true; tolerances.calibrationOffsetUs = 0
        let step = song.steps[1]
        _ = (step.id, step.kind, step.title, step.detail, step.firstMeasure, step.lastMeasure, step.hand, step.mode, step.tempoPercent)
        let timeline = song.score.timeline(passage: song.score.passage(measures: step.firstMeasure, step.lastMeasure), tempoPercent: 80)
        _ = (timeline.totalUs, timeline.beatTimesUs, timeline.downbeatTimesUs, timeline.measureIndex(atUs: 0), timeline.passage, timeline.otherHandAttacks(for: .right))
        var wait = WaitModeSession(timeline: timeline, hand: .both, tolerances: tolerances)
        let first = try XCTUnwrap(wait.currentGroup)
        _ = (first.attacks.map { $0.matchKey }, wait.remainingPitches, wait.groups.count, wait.index, wait.needsHint, wait.isFinished)
        let feedback = wait.handle(PerformanceEvent(seq: 1, type: .noteOn, pitch: first.attacks[0].midi, velocity: 70, channel: 1, pedalValue: nil, timeUs: 0, source: .bleMidi))
        if case .correct(_, let complete) = feedback { _ = complete }
        let report = RhythmEvaluator.evaluate(timeline: timeline, hand: .both, events: [], tolerances: tolerances)
        _ = (report.result, report.matchedCount, report.scoredCount, report.onTimeCount, report.missedCount, report.wrongCount, report.extraCount,
             report.excludedCount, report.assisted, report.troubleMeasures, report.mode, report.evaluations.first?.matchKey, report.evaluations.first?.classification)
        let technique = TechniqueMetrics.measure(timeline: timeline, report: report, events: [])
        _ = (technique.timingSpreadMs, technique.velocitySpread, technique.legatoShare, technique.legatoOverlapMs, technique.handBalance, technique.handSyncMs,
             technique.outliers.first?.reason, technique.outliers.first?.measureIndex)
        progress.techniqueHistory.append(AppProgress.TechniqueSample(date: Date(), songId: song.id, report: technique))
        var coach = Coach()
        let suggestion = coach.record(report, score: song.score, firstMeasure: 0, lastMeasure: 1, hand: .both, tempoPercent: 80)
        _ = (suggestion.action, suggestion.message, suggestion.tempoPercent, suggestion.firstMeasure, suggestion.lastMeasure, suggestion.hand)
        _ = Suggestion(action: .nextStep, message: "x")
        coach.reset()
        let trace = PerformanceTrace(header: TraceHeader(songId: song.id, passage: timeline.passage, hand: .both, mode: .rhythm, tempoPercent: 80,
                                                         calibrationOffsetUs: 0, inputName: "Piano"), events: [])
        _ = try trace.jsonLines()

        var active = ActiveNotes()
        active.apply(PerformanceEvent(seq: 0, type: .disconnect, pitch: nil, velocity: nil, pedalValue: nil, timeUs: 0))
        _ = active.held
        let message = try XCTUnwrap(MIDIDecoder.decode(umpWord: 0x2090_3C64))
        _ = (message.type, message.pitch, message.velocity, message.channel, message.pedalValue)

        let tonic = try XCTUnwrap(NoteName("F#"))
        let scale = TheoryScores.scale(tonic: tonic, type: .major, hand: .both, octaves: 1)
        _ = MusicXMLWriter.write(scale)
        _ = SongEntry(id: "scale", origin: .bundled, level: 1, score: scale)
        _ = TheoryScores.chords([ChordSpec(root: "C")])
        _ = (Theory.scale(NoteName(.c), .major).map { $0.description }, Theory.keyName(fifths: 1, minor: false), tonic.ascii, ScaleType.major.title)
        let chord = ChordSpec(root: "C", quality: .major, inversion: 1)
        _ = (chord.symbol, chord.pitches(above: 55).map { $0.midi }, chord.title)
        let exercises = ExerciseGenerator.make(GeneratorSpec(kind: .chordPlay, count: 2), seed: 1, idPrefix: "x")
        let e = try XCTUnwrap(exercises.first)
        _ = (e.usesPiano, e.kind, e.prompt, e.chord, e.requireInversion, e.chords, e.labels, e.rootMidi, e.semitones, e.options, e.answer, e.explanation, e.scaleTonic, e.scaleType, e.hand, e.octaves, e.id)
        _ = ExerciseChecker.chord(held: [60, 64, 67], spec: ChordSpec(root: "C"), requireInversion: false) == .correct
        _ = ExerciseChecker.interval(held: [62], rootMidi: 60, semitones: 2)
        _ = ExerciseChecker.choice(e, picked: 0)
        _ = (MIDINote.name(60), SpelledPitch.from(midi: 61).name)

        let block = try XCTUnwrap(lesson.blocks.first)
        _ = (block.text, block.keys, block.labels, block.scaleTonic, block.scaleType, block.hand, block.chords, block.chordLabels, block.exercise, block.generator, block.songId, block.items)
        _ = (lesson.title, lesson.summary, lesson.minutes, lesson.skillIds, lesson.sources, lesson.id)
        _ = block.generator.map { [.chordPlay, .intervalPlay, .romanPlay].contains($0.kind) }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("api-\(UUID().uuidString)")
        let store = ImportedSongStore(folder: folder)
        _ = store.loadAll()
        store.delete(id: "none")
        try ProgressStore.save(progress, to: folder.appendingPathComponent("p.json"))
        _ = ProgressStore.load(from: folder.appendingPathComponent("p.json"))
        _ = ScoreImportError.tooLarge.description
    }
}
