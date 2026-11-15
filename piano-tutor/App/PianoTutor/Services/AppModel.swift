import Foundation
import SwiftUI
import PianoCore

/// Everything the screens share: the song and lesson library, saved progress, the piano connection and sound.
final class AppModel: ObservableObject {
    let midi = MIDIManager()
    let sound = SoundPlayer()
    let pack: ContentPack
    private let importStore: ImportedSongStore
    private let progressURL: URL
    private let tracesFolder: URL

    @Published private(set) var songs: [SongEntry] = []
    @Published var progress: AppProgress { didSet { saveSoon() } }
    @Published private(set) var heldNotes: Set<Int> = []
    @Published private(set) var isPianoConnected = false
    @Published var importError: String?

    /// The practice screen sets this to receive every message with its exact time.
    var practiceHandler: ((MIDIDecoder.Message, Int64) -> Void)?
    var practiceConnectionHandler: ((Bool) -> Void)?
    private var active = ActiveNotes()
    private var saveScheduled = false

    init() {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let root = support.appendingPathComponent("PianoTutor", isDirectory: true)
        progressURL = root.appendingPathComponent("progress.json")
        tracesFolder = root.appendingPathComponent("traces", isDirectory: true)
        importStore = ImportedSongStore(folder: root.appendingPathComponent("imported", isDirectory: true))
        pack = ContentPack.loadBundled()
        progress = ProgressStore.load(from: progressURL)
        reloadSongs()
        isPianoConnected = midi.isConnected

        midi.onMessage = { [weak self] message, timeUs in
            guard let self else { return }
            self.active.apply(PerformanceEvent(seq: 0, type: message.type, pitch: message.pitch, velocity: message.velocity, pedalValue: message.pedalValue, timeUs: timeUs))
            self.heldNotes = self.active.held
            self.practiceHandler?(message, timeUs)
        }
        midi.onConnectionChange = { [weak self] connected in
            guard let self else { return }
            self.isPianoConnected = connected
            if !connected {
                self.active.apply(PerformanceEvent(seq: 0, type: .disconnect, timeUs: Clock.nowUs))
                self.heldNotes = []
            }
            self.practiceConnectionHandler?(connected)
        }
    }

    // MARK: Songs

    private func reloadSongs() {
        songs = ContentPack.ranked(pack.songs + importStore.loadAll())
    }

    func songs(level: Int) -> [SongEntry] { songs.filter { $0.level == level } }
    func song(_ id: String) -> SongEntry? { songs.first { $0.id == id } }

    func importSong(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            _ = try importStore.add(data: data, filename: url.lastPathComponent)
            reloadSongs()
        } catch let error as ScoreImportError {
            importError = error.description
        } catch {
            importError = "The file could not be read."
        }
    }

    func deleteSong(_ song: SongEntry) {
        guard song.origin == .imported else { return }
        importStore.delete(id: song.id)
        progress.songs[song.id] = nil
        reloadSongs()
    }

    func songProgress(_ id: String) -> SongProgress { progress.songs[id] ?? SongProgress(songId: id) }

    // MARK: Sound out

    var playsThroughPiano: Bool { progress.settings.demoThroughPiano && midi.canSend }

    func noteOn(_ note: Int, velocity: Int = 70) {
        if playsThroughPiano { midi.noteOn(note, velocity: velocity) } else { sound.noteOn(note, velocity: velocity) }
    }
    func noteOff(_ note: Int) {
        if playsThroughPiano { midi.noteOff(note) } else { sound.noteOff(note) }
    }
    func silence() {
        midi.allNotesOff()
        sound.silence()
    }

    /// Plays notes one after another and then together, for listening exercises.
    func playNotes(_ notes: [Int], together: Bool, gap: Double = 0.55) {
        var delay = 0.0
        if !together || notes.count > 1 {
            for note in notes where !together {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.noteOn(note) }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + gap * 0.9) { self.noteOff(note) }
                delay += gap
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { for note in notes { self.noteOn(note) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1.2) { for note in notes { self.noteOff(note) } }
    }

    // MARK: Progress

    func recordAttempt(song: SongEntry, step: LearningStep?, report: AttemptReport, technique: TechniqueReport?, seconds: Double, trace: PerformanceTrace) {
        var p = songProgress(song.id)
        p.attempts += 1
        p.lastPracticed = Date()
        if let step, report.result == .pass { p.completedSteps.insert(step.id) }
        if report.result == .pass, report.mode == .rhythm, step == nil || step?.kind == .wholeFull || step?.kind == .wholeSlow || step?.kind == .perform {
            p.bestFullTempoPercent = max(p.bestFullTempoPercent, trace.header.tempoPercent)
        }
        progress.songs[song.id] = p
        progress.practiceSeconds += seconds
        if report.result != .inconclusive, !song.skillIds.isEmpty, step?.kind == .wholeFull || step?.kind == .perform {
            progress.record(skills: song.skillIds, success: report.result == .pass)
        }
        if let technique, report.result == .pass, technique.timingSpreadMs != nil {
            progress.techniqueHistory.append(.init(date: Date(), songId: song.id, report: technique))
            if progress.techniqueHistory.count > 500 { progress.techniqueHistory.removeFirst(progress.techniqueHistory.count - 500) }
        }
        // Keep the last performance so a grading problem can be reproduced later.
        if let text = try? trace.jsonLines() {
            try? FileManager.default.createDirectory(at: tracesFolder, withIntermediateDirectories: true)
            try? Data(text.utf8).write(to: tracesFolder.appendingPathComponent("last-\(song.id).jsonl"), options: .atomic)
        }
    }

    func markStepDone(song: SongEntry, step: LearningStep) {
        var p = songProgress(song.id)
        p.completedSteps.insert(step.id)
        p.lastPracticed = Date()
        progress.songs[song.id] = p
    }

    func rate(song: SongEntry, rating: Int) {
        var p = songProgress(song.id)
        p.userRating = rating
        progress.songs[song.id] = p
    }

    func completeLesson(_ lesson: Lesson, score: Double) {
        var p = progress.lessons[lesson.id] ?? LessonProgress()
        p.completed = true
        p.bestScore = max(p.bestScore, score)
        p.lastOpened = Date()
        progress.lessons[lesson.id] = p
        progress.record(skills: lesson.skillIds, success: score >= 0.7)
    }

    func traceURL(for song: SongEntry) -> URL? {
        let url = tracesFolder.appendingPathComponent("last-\(song.id).jsonl")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func resetProgress() { progress = AppProgress() }

    private func saveSoon() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.saveScheduled = false
            try? ProgressStore.save(self.progress, to: self.progressURL)
        }
    }

    var tolerances: Tolerances {
        var t = Tolerances()
        t.strictChords = progress.settings.strictChords
        t.calibrationOffsetUs = Int64(progress.settings.calibrationOffsetMs) * 1000
        return t
    }
}
