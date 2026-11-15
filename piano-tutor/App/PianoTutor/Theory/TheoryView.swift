import SwiftUI
import PianoCore

/// The Theory section: two tracks, each a list of units and lessons.
struct TheoryView: View {
    @EnvironmentObject private var app: AppModel
    @State private var track: Track = .pianoTechnique

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Track", selection: $track) {
                        ForEach(Track.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(track == .pianoTechnique
                         ? "Skills at the keyboard: scales and fingering, chords under the hand, touch, balance and pedal."
                         : "How music is put together: rhythm, intervals, keys and chords.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(app.pack.units(in: track)) { unit in
                    Section {
                        ForEach(unit.lessons) { lesson in
                            NavigationLink { LessonView(lesson: lesson) } label: { LessonRow(lesson: lesson) }
                        }
                    } header: { Text(unit.title) } footer: { Text(unit.summary) }
                }
                Section {
                    Text("These lessons were written for this app and have not been reviewed by a piano teacher. The musical facts and every exercise answer are checked by the app's own tests. Treat the technique advice as a starting point, and have a teacher look at your playing when you can.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Theory")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ConnectionBadge() } }
        }
    }
}

struct LessonRow: View {
    @EnvironmentObject private var app: AppModel
    let lesson: Lesson

    init(lesson: Lesson) { self.lesson = lesson }

    var body: some View {
        let done = app.progress.lessons[lesson.id]?.completed ?? false
        let missing = lesson.skillIds.flatMap { app.pack.skill($0)?.prerequisites ?? [] }
            .filter { !(app.progress.skills[$0]?.correct ?? 0 > 0) && !lesson.skillIds.contains($0) }
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title).font(.headline)
                Text(lesson.summary).font(.subheadline).foregroundStyle(.secondary)
                if !done, let first = missing.first, let skill = app.pack.skill(first) {
                    Text("Builds on: \(skill.title)").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            Text("\(lesson.minutes) min").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// A repeatable number from text, so generated questions stay the same between launches.
func stableSeed(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in text.utf8 { hash ^= UInt64(byte); hash = hash &* 0x0000_0100_0000_01B3 }
    return hash
}

struct LessonView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let lesson: Lesson
    /// Block index → share of questions answered right first time.
    @State private var results: [Int: Double] = [:]

    init(lesson: Lesson) { self.lesson = lesson }

    private func needsPiano(_ block: LessonBlock) -> Bool {
        if let e = block.exercise { return e.usesPiano && e.kind != .playScale }
        if let g = block.generator { return [.chordPlay, .intervalPlay, .romanPlay].contains(g.kind) }
        return false
    }

    /// Only one keyboard question listens at a time: the first one not yet answered.
    private var activePianoBlock: Int? {
        lesson.blocks.indices.first { needsPiano(lesson.blocks[$0]) && results[$0] == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(lesson.summary).font(.title3).foregroundStyle(.secondary)
                ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { index, block in
                    BlockView(lessonId: lesson.id, index: index, block: block, isActive: activePianoBlock == index) { score in
                        results[index] = score
                    }
                }
                if let sources = lesson.sources, !sources.isEmpty {
                    Text("Sources: " + sources.joined(separator: " ")).font(.footnote).foregroundStyle(.secondary)
                }
                Button {
                    let scores = Array(results.values)
                    app.completeLesson(lesson, score: scores.isEmpty ? 1 : scores.reduce(0, +) / Double(scores.count))
                    dismiss()
                } label: {
                    Label("Finish lesson", systemImage: "checkmark").font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ConnectionBadge() } }
        .onDisappear { app.silence() }
    }
}

struct BlockView: View {
    @EnvironmentObject private var app: AppModel
    let lessonId: String
    let index: Int
    let block: LessonBlock
    let isActive: Bool
    let onResult: (Double) -> Void
    @State private var checked: Set<Int> = []

    var body: some View {
        switch block.type {
        case .text:
            Text(block.text ?? "").font(.body).fixedSize(horizontal: false, vertical: true)
        case .keyboard:
            let keys = block.keys ?? []
            VStack(alignment: .leading, spacing: 8) {
                KeyboardView(lowest: (keys.min() ?? 60) - 5, highest: (keys.max() ?? 72) + 7,
                             marks: Dictionary(uniqueKeysWithValues: Array(Set(keys)).map { ($0, KeyMark.shown) }),
                             labels: labels(for: keys), onTap: { note in app.playNotes([note], together: true) })
                    .frame(height: 120).frame(maxWidth: 560)
                HStack {
                    Button { app.playNotes(keys, together: false, gap: 0.5) } label: { Label("Listen", systemImage: "speaker.wave.2") }
                        .buttonStyle(.bordered)
                    if let caption = block.text { Text(caption).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
        case .scale:
            let tonic = NoteName(block.scaleTonic ?? "C") ?? NoteName(.c)
            let type = block.scaleType ?? .major
            let score = TheoryScores.scale(tonic: tonic, type: type, hand: block.hand ?? .right)
            VStack(alignment: .leading, spacing: 8) {
                NotationSnippet(xml: MusicXMLWriter.write(score), height: (block.hand ?? .right) == .both ? 260 : 250)
                HStack {
                    Button { playLine(score) } label: { Label("Listen", systemImage: "speaker.wave.2") }.buttonStyle(.bordered)
                    Text(block.text ?? "\(tonic) \(type.title): \(Theory.scale(tonic, type).prefix(7).map { $0.description }.joined(separator: " "))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        case .chords, .listen:
            let specs = block.chords ?? []
            VStack(alignment: .leading, spacing: 8) {
                if !specs.isEmpty { NotationSnippet(xml: MusicXMLWriter.write(TheoryScores.chords(specs)), height: 250) }
                HStack(spacing: 10) {
                    Button { playChords(specs) } label: { Label("Listen", systemImage: "speaker.wave.2") }.buttonStyle(.bordered)
                    ForEach(Array(specs.enumerated()), id: \.offset) { i, spec in
                        Text((block.chordLabels?.indices.contains(i) ?? false) ? block.chordLabels![i] : spec.symbol)
                            .font(.subheadline.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
                if let caption = block.text { Text(caption).font(.subheadline).foregroundStyle(.secondary) }
            }
        case .checklist:
            VStack(alignment: .leading, spacing: 10) {
                if let caption = block.text { Text(caption).font(.headline) }
                ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { i, item in
                    Button {
                        if checked.contains(i) { checked.remove(i) } else { checked.insert(i) }
                        if checked.count == (block.items ?? []).count { onResult(1) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: checked.contains(i) ? "checkmark.square.fill" : "square").font(.title3)
                            Text(item).multilineTextAlignment(.leading).foregroundStyle(.primary)
                        }
                        .frame(minHeight: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        case .songLink:
            if let song = app.song(block.songId ?? "") {
                NavigationLink { SongDetailView(song: song) } label: {
                    HStack {
                        Image(systemName: "music.note").font(.title3)
                        VStack(alignment: .leading) {
                            Text("In a piece: \(song.title)").font(.headline)
                            if let caption = block.text { Text(caption).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding(14).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        case .exercise:
            if let exercise = block.exercise {
                ExerciseCard(exercise: exercise, isActive: isActive) { firstTry in onResult(firstTry ? 1 : 0) }
            }
        case .generated:
            if let generator = block.generator {
                GeneratedSet(spec: generator, baseSeed: stableSeed("\(lessonId)#\(index)"), caption: block.text, isActive: isActive, onResult: onResult)
            }
        }
    }

    private func labels(for keys: [Int]) -> [Int: String] {
        var result: [Int: String] = [:]
        for (i, key) in keys.enumerated() {
            result[key] = (block.labels?.indices.contains(i) ?? false) ? block.labels![i] : SpelledPitch.from(midi: key).name
        }
        return result
    }

    private func playLine(_ score: Score) {
        let timeline = score.timeline(passage: score.wholePassage, tempoPercent: 130)
        for a in timeline.attacks {
            let start = Double(a.timeUs) / 1_000_000
            DispatchQueue.main.asyncAfter(deadline: .now() + start) { app.noteOn(a.midi, velocity: 70) }
            DispatchQueue.main.asyncAfter(deadline: .now() + start + Double(a.durationUs) / 1_000_000 * 0.9) { app.noteOff(a.midi) }
        }
    }

    private func playChords(_ specs: [ChordSpec]) {
        for (i, spec) in specs.enumerated() {
            let notes = spec.pitches(above: 55).map { $0.midi }
            let start = Double(i) * 1.3
            DispatchQueue.main.asyncAfter(deadline: .now() + start) { for n in notes { app.noteOn(n, velocity: 68) } }
            DispatchQueue.main.asyncAfter(deadline: .now() + start + 1.1) { for n in notes { app.noteOff(n) } }
        }
    }
}

/// A run of generated questions, shown one at a time.
struct GeneratedSet: View {
    let spec: GeneratorSpec
    let baseSeed: UInt64
    let caption: String?
    let isActive: Bool
    let onResult: (Double) -> Void
    @State private var round: UInt64 = 0
    @State private var position = 0
    @State private var firstTryCorrect = 0
    @State private var currentSolved = false

    private var exercises: [Exercise] { ExerciseGenerator.make(spec, seed: baseSeed &+ round, idPrefix: "g\(baseSeed % 100_000).\(round)") }

    var body: some View {
        let list = exercises
        VStack(alignment: .leading, spacing: 10) {
            if let caption { Text(caption).font(.headline) }
            if position < list.count {
                Text("Question \(position + 1) of \(list.count)").font(.caption).foregroundStyle(.secondary)
                ExerciseCard(exercise: list[position], isActive: isActive) { firstTry in
                    if firstTry { firstTryCorrect += 1 }
                    currentSolved = true
                }
                .id(list[position].id)
                if currentSolved {
                    Button(position + 1 < list.count ? "Next question" : "Finish these") {
                        position += 1
                        currentSolved = false
                        if position >= list.count { onResult(Double(firstTryCorrect) / Double(max(list.count, 1))) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                HStack {
                    Label("\(firstTryCorrect) of \(list.count) right first time", systemImage: "checkmark.seal").font(.headline)
                    Spacer()
                    Button("More questions") { round += 1; position = 0; firstTryCorrect = 0; currentSolved = false }.buttonStyle(.bordered)
                }
                .padding(14).background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

/// One question, answered by tapping or on the piano.
struct ExerciseCard: View {
    @EnvironmentObject private var app: AppModel
    let exercise: Exercise
    let isActive: Bool
    /// Called once when the question is answered correctly; the flag says whether the first answer was right.
    let onSolved: (Bool) -> Void

    @State private var wrongPicks: Set<Int> = []
    @State private var solved = false
    @State private var hadMistake = false
    @State private var status = ""
    @State private var chordIndex = 0
    @State private var showScale = false
    @State private var scaleResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: exercise.usesPiano ? "pianokeys" : "questionmark.circle").font(.title3).foregroundStyle(.blue)
                Text(promptText).font(.headline).fixedSize(horizontal: false, vertical: true)
            }
            content
            if solved, let explanation = exercise.explanation {
                Label(explanation, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.subheadline)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(solved ? Color.green.opacity(0.6) : (isActive && exercise.usesPiano ? Color.blue.opacity(0.6) : Color.clear), lineWidth: 2))
        .onChange(of: app.heldNotes) { _, held in pianoChanged(held) }
        .sheet(isPresented: $showScale) { scaleSheet }
    }

    private var promptText: String {
        if exercise.kind == .playProgression, let chords = exercise.chords, chordIndex < chords.count, !solved {
            let label = (exercise.labels?.indices.contains(chordIndex) ?? false) ? exercise.labels![chordIndex] : chords[chordIndex].symbol
            return "\(exercise.prompt)\nNow play: \(label) (\(chordIndex + 1) of \(chords.count))"
        }
        return exercise.prompt
    }

    @ViewBuilder
    private var content: some View {
        switch exercise.kind {
        case .choice, .earInterval, .earChord:
            if exercise.kind != .choice {
                Button { listen() } label: { Label("Play it", systemImage: "speaker.wave.2.fill").frame(minHeight: 40) }.buttonStyle(.borderedProminent)
            }
            let options = exercise.options ?? []
            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    Button { pick(i) } label: {
                        HStack {
                            Text(option).multilineTextAlignment(.leading)
                            Spacer()
                            if solved && i == exercise.answer { Image(systemName: "checkmark").accessibilityLabel("Correct") }
                            if wrongPicks.contains(i) { Image(systemName: "xmark").accessibilityLabel("Not this one") }
                        }
                        .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 46)
                        .background((solved && i == exercise.answer) ? Color.green.opacity(0.22) : (wrongPicks.contains(i) ? Color.red.opacity(0.16) : Color(.tertiarySystemBackground)),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(solved || wrongPicks.contains(i))
                }
            }
        case .playChord, .playInterval, .playProgression:
            if !solved {
                if !app.isPianoConnected {
                    Label("Connect your piano to answer this on the keys.", systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(.orange)
                    Button("Show me the answer") { reveal() }.buttonStyle(.bordered)
                } else if isActive {
                    Text(status.isEmpty ? "Play it on your piano and hold the keys." : status).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Answer the earlier keyboard question first.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        case .playScale:
            HStack {
                Button { showScale = true } label: { Label(solved ? "Play it again" : "Open the scale", systemImage: "play.fill").frame(minHeight: 40) }
                    .buttonStyle(.borderedProminent)
                if let scaleResult { Text(scaleResult).font(.subheadline).foregroundStyle(.secondary) }
            }
        }
    }

    private func listen() {
        if exercise.kind == .earInterval, let root = exercise.rootMidi, let semis = exercise.semitones {
            app.playNotes([root, root + semis], together: false)
        } else if let chord = exercise.chord {
            app.playNotes(chord.pitches(above: 55).map { $0.midi }, together: true)
        }
    }

    private func pick(_ i: Int) {
        if ExerciseChecker.choice(exercise, picked: i) { finish() } else { wrongPicks.insert(i); hadMistake = true }
    }

    private func reveal() {
        hadMistake = true
        if let chord = exercise.chord { app.playNotes(chord.pitches(above: 55).map { $0.midi }, together: true) }
        finish()
    }

    private func finish() {
        guard !solved else { return }
        solved = true
        onSolved(!hadMistake)
    }

    private func pianoChanged(_ held: Set<Int>) {
        guard isActive, !solved, exercise.usesPiano, exercise.kind != .playScale else { return }
        let answer: ChordAnswer
        switch exercise.kind {
        case .playChord:
            guard let chord = exercise.chord else { return }
            answer = ExerciseChecker.chord(held: held, spec: chord, requireInversion: exercise.requireInversion ?? false)
        case .playInterval:
            answer = ExerciseChecker.interval(held: held, rootMidi: exercise.rootMidi ?? 60, semitones: exercise.semitones ?? 0)
        case .playProgression:
            guard let chords = exercise.chords, chordIndex < chords.count else { return }
            answer = ExerciseChecker.chord(held: held, spec: chords[chordIndex], requireInversion: chords[chordIndex].inversion != 0)
        default: return
        }
        switch answer {
        case .correct:
            if exercise.kind == .playProgression, let chords = exercise.chords, chordIndex + 1 < chords.count {
                chordIndex += 1
                status = "Good. Next chord."
            } else { finish() }
        case .incomplete(let missing):
            status = "Keep going: still needs \(missing.joined(separator: ", "))."
        case .wrongNotes(let extra):
            hadMistake = true
            status = "\(extra.map { MIDINote.name($0) }.joined(separator: ", ")) \(extra.count == 1 ? "does" : "do") not belong. Let go and try again."
        case .wrongInversion(let bass):
            hadMistake = true
            status = "Right notes, but \(bass) should be the lowest."
        case .nothing:
            break
        }
    }

    private var scaleSheet: some View {
        let tonic = NoteName(exercise.scaleTonic ?? "C") ?? NoteName(.c)
        let type = exercise.scaleType ?? .major
        let hand = exercise.hand ?? .right
        let score = TheoryScores.scale(tonic: tonic, type: type, hand: hand, octaves: exercise.octaves ?? 1)
        let entry = SongEntry(id: "scale-\(tonic.ascii)-\(type.rawValue)-\(hand.rawValue)", origin: .bundled, level: 1, score: score)
        return NavigationStack {
            PracticeView(app: app, song: entry) { report, technique in
                if report.result == .pass {
                    var parts: [String] = ["Clean."]
                    if let spread = technique?.timingSpreadMs { parts.append(String(format: "Timing spread %.0f ms.", spread)) }
                    if let share = technique?.legatoShare { parts.append(String(format: "%.0f%% of notes joined.", share * 100)) }
                    scaleResult = parts.joined(separator: " ")
                    finish()
                } else if report.result == .fail {
                    hadMistake = true
                    scaleResult = "Not clean yet. Try again slowly."
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showScale = false } } }
        }
    }
}
