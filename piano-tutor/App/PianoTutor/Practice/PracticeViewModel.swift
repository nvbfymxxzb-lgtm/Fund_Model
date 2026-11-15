import Foundation
import SwiftUI
import PianoCore

/// Runs one practice screen: demonstration, wait mode, rhythm mode, grading and the suggestion afterwards.
final class PracticeViewModel: ObservableObject {
    enum Phase: Equatable { case idle, demo, countIn, playing, finished }

    let app: AppModel
    let song: SongEntry
    let notation = NotationController()
    /// When set, the screen is an exercise from a lesson and finishing reports back instead of saving song progress.
    var onExerciseFinished: ((AttemptReport, TechniqueReport?) -> Void)?

    @Published var step: LearningStep?
    @Published var firstMeasure: Int
    @Published var lastMeasure: Int
    @Published var hand: HandSelection
    @Published var mode: PracticeMode
    @Published var tempoPercent: Int
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var keyMarks: [Int: KeyMark] = [:]
    @Published private(set) var keyLabels: [Int: String] = [:]
    @Published private(set) var feedback = ""
    @Published private(set) var countInText: String?
    @Published private(set) var report: AttemptReport?
    @Published private(set) var suggestion: Suggestion?
    @Published private(set) var technique: TechniqueReport?
    @Published private(set) var progressFraction: Double = 0
    @Published var showSummary = false

    private var timeline: PassageTimeline?
    private var wait: WaitModeSession?
    private var events: [PerformanceEvent] = []
    private var seq: Int64 = 0
    private var startUs: Int64 = 0
    private let sequencer = Sequencer()
    private var coach = Coach()
    private var attemptBegan = Date()
    private var held: Set<Int> = []
    private var wrongHeld: Set<Int> = []
    private var correctHeld: Set<Int> = []
    private var expectedNow: Set<Int> = []
    private var litAttacks: Set<String> = []
    private var soundingDemo: Set<Int> = []

    var score: Score { song.score }
    var isBusy: Bool { phase == .demo || phase == .countIn || phase == .playing }

    init(app: AppModel, song: SongEntry, step: LearningStep? = nil) {
        self.app = app
        self.song = song
        self.step = step
        let last = max(song.score.measures.count - 1, 0)
        firstMeasure = step?.firstMeasure ?? 0
        lastMeasure = step?.lastMeasure ?? last
        hand = step?.hand ?? .both
        mode = step?.mode ?? .wait
        tempoPercent = step?.tempoPercent ?? 100
        notation.onMeasureTapped = { [weak self] measure in self?.measureTapped(measure) }
    }

    // MARK: Screen life cycle

    func appear() {
        notation.load(xml: song.displayXML, zoom: 1.0)
        notation.setRange(first: firstMeasure, last: lastMeasure)
        notation.scrollToMeasure(firstMeasure)
        app.practiceHandler = { [weak self] message, timeUs in self?.handle(message, timeUs: timeUs) }
        app.practiceConnectionHandler = { [weak self] connected in self?.connectionChanged(connected) }
        feedback = openingHint
        refreshKeyboard()
    }

    func disappear() {
        stop()
        app.practiceHandler = nil
        app.practiceConnectionHandler = nil
    }

    private var openingHint: String {
        if !app.isPianoConnected { return "Connect your piano to be graded. You can still listen to the demonstration." }
        if step?.kind == .listen { return "Press Listen to hear the piece." }
        return mode == .wait ? "Press Start. The music waits until you play the right notes." : "Press Start. After the count-in, play in time with the beat."
    }

    func apply(step newStep: LearningStep) {
        stop()
        step = newStep
        firstMeasure = newStep.firstMeasure; lastMeasure = newStep.lastMeasure
        hand = newStep.hand; mode = newStep.mode; tempoPercent = newStep.tempoPercent
        coach.reset()
        passageChanged()
        feedback = newStep.detail
    }

    func passageChanged() {
        if lastMeasure < firstMeasure { lastMeasure = firstMeasure }
        notation.clearMarks()
        notation.setRange(first: firstMeasure, last: lastMeasure)
        notation.scrollToMeasure(firstMeasure)
        report = nil; suggestion = nil; technique = nil
        phase = .idle
        refreshKeyboard()
    }

    private func measureTapped(_ measure: Int) {
        guard !isBusy, score.measures.indices.contains(measure) else { return }
        // A tap starts a one-measure loop there. A second tap on a later measure extends the loop to it.
        if firstMeasure == lastMeasure && measure > firstMeasure { lastMeasure = measure }
        else { firstMeasure = measure; lastMeasure = measure }
        step = nil
        passageChanged()
    }

    func selectWholePiece() {
        firstMeasure = 0; lastMeasure = max(score.measures.count - 1, 0); step = nil
        passageChanged()
    }

    /// The range of piano keys worth drawing for this passage.
    var keyboardRange: ClosedRange<Int> {
        let notes = score.notes.filter { $0.measureIndex >= firstMeasure && $0.measureIndex <= lastMeasure }.map { $0.midi }
        var low = (notes.min() ?? 48) - 3, high = (notes.max() ?? 84) + 3
        while high - low < 36 { low -= 2; high += 2 }
        return max(21, low - (low % 12))...min(108, high + (11 - high % 12))
    }

    private func makeTimeline(tempo: Int) -> PassageTimeline {
        score.timeline(passage: score.passage(measures: firstMeasure, lastMeasure), tempoPercent: tempo)
    }

    // MARK: Stop

    func stop() {
        sequencer.stop()
        for note in soundingDemo { app.noteOff(note) }
        soundingDemo = []
        app.silence()
        countInText = nil
        if phase != .finished { phase = .idle }
        notation.setCurrent([], scroll: false)
        expectedNow = []
        refreshKeyboard()
    }

    // MARK: Demonstration

    func playDemo() {
        stop()
        notation.clearMarks()
        let t = makeTimeline(tempo: tempoPercent)
        timeline = t
        var items: [Sequencer.Item] = []
        let attacks = t.attacks(for: hand)
        for group in Dictionary(grouping: attacks, by: { $0.timeUs }).sorted(by: { $0.key < $1.key }) {
            let keys = group.value.map { $0.matchKey }
            items.append(.init(timeUs: group.key) { [weak self] in self?.notation.setCurrent(keys) })
        }
        for a in attacks {
            let velocity = a.hand == .right ? 78 : 62
            items.append(.init(timeUs: a.timeUs) { [weak self] in self?.demoNote(a.midi, on: true, velocity: velocity) })
            items.append(.init(timeUs: a.timeUs + max(a.durationUs - 30_000, 40_000)) { [weak self] in self?.demoNote(a.midi, on: false, velocity: 0) })
        }
        items.append(.init(timeUs: t.totalUs + 200_000) { [weak self] in self?.demoFinished() })
        phase = .demo
        feedback = "Listening…"
        sequencer.start(items: items, startUs: Clock.nowUs + 250_000)
    }

    private func demoNote(_ note: Int, on: Bool, velocity: Int) {
        if on { app.noteOn(note, velocity: velocity); soundingDemo.insert(note) } else { app.noteOff(note); soundingDemo.remove(note) }
        refreshKeyboard()
    }

    private func demoFinished() {
        stop()
        if let step, step.kind == .listen, onExerciseFinished == nil {
            app.markStepDone(song: song, step: step)
            feedback = "That is the whole piece. Move on to the first phrase."
            suggestion = Suggestion(action: .nextStep, message: feedback)
        } else {
            feedback = "Now you try."
        }
    }

    // MARK: Start an attempt

    func start() {
        stop()
        notation.clearMarks()
        events = []; seq = 0; litAttacks = []; wrongHeld = []; correctHeld = []
        report = nil; suggestion = nil; technique = nil
        attemptBegan = Date()
        if mode == .wait { startWait() } else { startRhythm() }
    }

    private func startWait() {
        let t = makeTimeline(tempo: 100)
        timeline = t
        wait = WaitModeSession(timeline: t, hand: hand, tolerances: app.tolerances)
        startUs = Clock.nowUs
        phase = .playing
        feedback = "Play the blue notes."
        updateWaitCursor()
    }

    private func updateWaitCursor() {
        guard let wait else { return }
        if let group = wait.currentGroup {
            notation.setCurrent(group.attacks.map { $0.matchKey })
            expectedNow = wait.remainingPitches
            progressFraction = wait.groups.isEmpty ? 0 : Double(wait.index) / Double(wait.groups.count)
        } else {
            expectedNow = []
            progressFraction = 1
        }
        refreshKeyboard()
    }

    private func startRhythm() {
        let t = makeTimeline(tempo: tempoPercent)
        timeline = t
        wait = nil
        let firstBar = score.measures[min(max(firstMeasure, 0), max(score.measures.count - 1, 0))]
        let beatUs: Int64 = t.beatTimesUs.count > 1 ? max(t.beatTimesUs[1] - t.beatTimesUs[0], 100_000) : 500_000
        let fullBeats = max(1, Int((firstBar.time.length / firstBar.time.beatLength).doubleValue.rounded()))
        var countBeats = fullBeats
        if firstBar.isPickup {
            let pickupBeats = Int((firstBar.length / firstBar.time.beatLength).doubleValue.rounded(.up))
            countBeats = fullBeats - pickupBeats
            if countBeats < 2 { countBeats += fullBeats }
        }
        var items: [Sequencer.Item] = []
        for i in 0..<countBeats {
            let time = -Int64(countBeats - i) * beatUs
            let number = i + 1
            items.append(.init(timeUs: time) { [weak self] in
                self?.countInText = "\(number)"
                self?.app.sound.click(accent: number == 1)
            })
        }
        items.append(.init(timeUs: 0) { [weak self] in self?.countInText = nil; self?.phase = .playing })
        if app.progress.settings.metronomeOn {
            for beat in t.beatTimesUs {
                let accent = t.downbeatTimesUs.contains(beat)
                items.append(.init(timeUs: beat) { [weak self] in self?.app.sound.click(accent: accent) })
            }
        }
        let mine = t.attacks(for: hand)
        for group in Dictionary(grouping: mine, by: { $0.timeUs }).sorted(by: { $0.key < $1.key }) {
            let keys = group.value.map { $0.matchKey }
            let pitches = Set(group.value.map { $0.midi })
            let fraction = t.totalUs > 0 ? Double(group.key) / Double(t.totalUs) : 0
            items.append(.init(timeUs: group.key) { [weak self] in
                self?.notation.setCurrent(keys)
                self?.expectedNow = pitches
                self?.progressFraction = fraction
                self?.refreshKeyboard()
            })
        }
        if app.progress.settings.accompanyOtherHand {
            for a in t.otherHandAttacks(for: hand) {
                items.append(.init(timeUs: a.timeUs) { [weak self] in self?.demoNote(a.midi, on: true, velocity: 55) })
                items.append(.init(timeUs: a.timeUs + max(a.durationUs - 30_000, 40_000)) { [weak self] in self?.demoNote(a.midi, on: false, velocity: 0) })
            }
        }
        items.append(.init(timeUs: t.totalUs + 450_000) { [weak self] in self?.finishRhythm() })
        startUs = Clock.nowUs + 300_000 + Int64(countBeats) * beatUs
        phase = .countIn
        feedback = "Count in…"
        sequencer.start(items: items, startUs: startUs)
    }

    // MARK: Input

    private func handle(_ message: MIDIDecoder.Message, timeUs: Int64) {
        switch message.type {
        case .noteOn: if let p = message.pitch { held.insert(p) }
        case .noteOff: if let p = message.pitch { held.remove(p); wrongHeld.remove(p); correctHeld.remove(p) }
        case .allNotesOff: held = []; wrongHeld = []; correctHeld = []
        default: break
        }
        defer { refreshKeyboard() }
        guard phase == .playing || phase == .countIn else { return }
        seq += 1
        let event = PerformanceEvent(seq: seq, type: message.type, pitch: message.pitch, velocity: message.velocity, channel: message.channel,
                                     pedalValue: message.pedalValue, timeUs: timeUs - startUs, source: .bleMidi)
        events.append(event)
        guard message.type == .noteOn, let pitch = message.pitch else { return }
        if mode == .wait { handleWait(event, pitch: pitch) } else { handleRhythmLive(event, pitch: pitch) }
    }

    private func handleWait(_ event: PerformanceEvent, pitch: Int) {
        guard var session = wait else { return }
        let groupBefore = session.currentGroup
        let result = session.handle(event)
        wait = session
        switch result {
        case .correct(_, let complete):
            correctHeld.insert(pitch)
            if let group = groupBefore {
                notation.mark(group.attacks.filter { $0.midi == pitch }.map { $0.matchKey }, state: "correct")
            }
            if complete { feedback = session.isFinished ? "" : "Good." }
            updateWaitCursor()
            if session.isFinished { finishWait() }
        case .wrong(_, let octave):
            wrongHeld.insert(pitch)
            let wanted = session.remainingPitches.sorted().map { MIDINote.name($0) }.joined(separator: ", ")
            if octave { feedback = "Right note, wrong octave. Look for the blue key." }
            else if session.needsHint { feedback = "Not \(MIDINote.name(pitch)). The note\(session.remainingPitches.count == 1 ? " is" : "s are") \(wanted)." }
            else { feedback = "Not \(MIDINote.name(pitch)). Find the blue key." }
        case .chordTooSpread:
            correctHeld.insert(pitch)
            feedback = "Play the notes of the chord together."
            updateWaitCursor()
        case .otherHand, .ignored, .paused, .finished:
            break
        }
    }

    private func handleRhythmLive(_ event: PerformanceEvent, pitch: Int) {
        guard let t = timeline else { return }
        let tolerances = app.tolerances
        let time = event.timeUs - tolerances.calibrationOffsetUs
        let candidates = t.attacks(for: hand).filter { $0.midi == pitch && !litAttacks.contains($0.id) && abs($0.timeUs - time) <= tolerances.acceptUs }
        if let best = candidates.min(by: { abs($0.timeUs - time) < abs($1.timeUs - time) }) {
            litAttacks.insert(best.id)
            correctHeld.insert(pitch)
            notation.mark([best.matchKey], state: abs(best.timeUs - time) <= tolerances.onTimeUs ? "correct" : "late")
        } else if !t.otherHandAttacks(for: hand).contains(where: { $0.midi == pitch && abs($0.timeUs - time) <= tolerances.acceptUs }) {
            wrongHeld.insert(pitch)
        }
    }

    private func connectionChanged(_ connected: Bool) {
        guard !connected, phase == .playing || phase == .countIn else { return }
        seq += 1
        let event = PerformanceEvent(seq: seq, type: .disconnect, timeUs: Clock.nowUs - startUs)
        events.append(event)
        held = []; wrongHeld = []; correctHeld = []
        if mode == .wait {
            if var session = wait { _ = session.handle(event); wait = session }
            feedback = "The piano disconnected. Practice is paused and nothing is being marked wrong. Reconnect, then press Start."
            finishWait()
        } else {
            sequencer.stop()
            finishRhythm()
        }
    }

    // MARK: Finish

    private func finishWait() {
        guard let session = wait, let t = timeline else { return }
        finish(session.report(), timeline: t)
    }

    private func finishRhythm() {
        guard let t = timeline, phase == .playing || phase == .countIn else { return }
        sequencer.stop()
        for note in soundingDemo { app.noteOff(note) }
        soundingDemo = []
        let result = RhythmEvaluator.evaluate(timeline: t, hand: hand, events: events, tolerances: app.tolerances)
        notation.clearMarks()
        var byState: [String: [String]] = [:]
        for e in result.evaluations {
            guard let key = e.matchKey else { continue }
            switch e.classification {
            case .onTime, .hit: byState["correct", default: []].append(key)
            case .early, .late: byState["late", default: []].append(key)
            case .missed, .wrongPitch: byState["missed", default: []].append(key)
            case .extra, .excluded: break
            }
        }
        for (state, keys) in byState { notation.mark(keys, state: state) }
        finish(result, timeline: t)
    }

    private func finish(_ result: AttemptReport, timeline t: PassageTimeline) {
        phase = .finished
        countInText = nil
        expectedNow = []
        notation.setCurrent([], scroll: false)
        report = result
        let measured = TechniqueMetrics.measure(timeline: t, report: result, events: events)
        technique = measured
        let advice = coach.record(result, score: score, firstMeasure: firstMeasure, lastMeasure: lastMeasure, hand: hand, tempoPercent: tempoPercent)
        suggestion = advice
        feedback = advice.message
        progressFraction = 1
        let trace = PerformanceTrace(header: TraceHeader(songId: song.id, passage: t.passage, hand: hand, mode: mode, tempoPercent: mode == .rhythm ? tempoPercent : 100,
                                                         calibrationOffsetUs: app.tolerances.calibrationOffsetUs, inputName: app.midi.sourceNames.first ?? ""),
                                     events: events)
        if let onExerciseFinished {
            onExerciseFinished(result, measured)
        } else {
            app.recordAttempt(song: song, step: step, report: result, technique: measured, seconds: Date().timeIntervalSince(attemptBegan), trace: trace)
        }
        refreshKeyboard()
        showSummary = true
    }

    // MARK: After an attempt

    var nextStep: LearningStep? {
        guard let step, let index = song.steps.firstIndex(where: { $0.id == step.id }), index + 1 < song.steps.count else { return nil }
        return song.steps[index + 1]
    }

    func applySuggestion() {
        guard let s = suggestion else { return }
        switch s.action {
        case .nextStep:
            if let next = nextStep { apply(step: next) }
        case .speedUp, .slowDown:
            if let tempo = s.tempoPercent { tempoPercent = tempo }
            passageChanged()
        case .shortenLoop:
            if let a = s.firstMeasure, let b = s.lastMeasure { firstMeasure = a; lastMeasure = b }
            passageChanged()
        case .oneHand:
            hand = s.hand ?? .right
            passageChanged()
        case .repeatSame, .checkConnection:
            passageChanged()
        }
        showSummary = false
    }

    var suggestionButtonTitle: String {
        switch suggestion?.action {
        case .nextStep: return nextStep == nil ? "Done" : "Next step"
        case .speedUp: return "Try it faster"
        case .slowDown: return "Slow down"
        case .shortenLoop: return "Loop the hard spot"
        case .oneHand: return "One hand"
        case .checkConnection: return "OK"
        case .repeatSame, .none: return "Try again"
        }
    }

    // MARK: Keyboard picture

    private func refreshKeyboard() {
        var marks: [Int: KeyMark] = [:]
        var labels: [Int: String] = [:]
        let showNames = app.progress.settings.showNoteNames || (wait?.needsHint ?? false)
        if phase == .playing || phase == .countIn {
            for note in expectedNow { marks[note] = .expected; if showNames { labels[note] = SpelledPitch.from(midi: note).name } }
        }
        for note in soundingDemo { marks[note] = .shown }
        for note in held {
            if wrongHeld.contains(note) { marks[note] = .wrong }
            else if correctHeld.contains(note) { marks[note] = .correct }
            else if marks[note] == nil { marks[note] = .neutral }
        }
        keyMarks = marks
        keyLabels = labels
    }
}
