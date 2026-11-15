import SwiftUI
import UniformTypeIdentifiers
import PianoCore

/// The song library, ranked from easiest to hardest.
struct SongsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showImporter = false
    @State private var skillFilter: String?

    private var importTypes: [UTType] {
        var types: [UTType] = [.xml]
        if let t = UTType(filenameExtension: "musicxml") { types.append(t) }
        if let t = UTType(filenameExtension: "mxl") { types.append(t) }
        return types
    }

    private var visibleSongs: [SongEntry] {
        guard let skillFilter else { return app.songs }
        return app.songs.filter { $0.skillIds.contains(skillFilter) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let next = suggested {
                    Section("Continue") {
                        NavigationLink(value: next.id) { SongRow(song: next, highlight: true) }
                    }
                }
                ForEach(1...6, id: \.self) { level in
                    let songs = visibleSongs.filter { $0.level == level }
                    if !songs.isEmpty {
                        Section {
                            ForEach(songs) { song in
                                NavigationLink(value: song.id) { SongRow(song: song, highlight: false) }
                                    .swipeActions {
                                        if song.origin == .imported {
                                            Button("Delete", role: .destructive) { app.deleteSong(song) }
                                        }
                                    }
                            }
                        } header: { Text("Level \(level) · \(SongsView.levelName(level))") }
                    }
                }
                Section {
                    Text("Songs are ordered by level, and within a level by a difficulty score the app works out from the notes. The levels and scores are this app's own estimates and have not been checked by a teacher.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Songs")
            .navigationDestination(for: String.self) { id in
                if let song = app.song(id) { SongDetailView(song: song) } else { Text("This song is no longer in the library.") }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ConnectionBadge() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All songs") { skillFilter = nil }
                        ForEach(app.pack.skills.filter { skill in app.songs.contains { $0.skillIds.contains(skill.id) } }) { skill in
                            Button(skill.title) { skillFilter = skill.id }
                        }
                    } label: { Label(skillFilter.flatMap { app.pack.skill($0)?.title } ?? "Filter", systemImage: "line.3.horizontal.decrease.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImporter = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: importTypes, allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first { app.importSong(from: url) }
            }
            .alert("Could not import", isPresented: Binding(get: { app.importError != nil }, set: { if !$0 { app.importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(app.importError ?? "") }
        }
    }

    /// The song being learned, or the easiest one not yet started.
    private var suggested: SongEntry? {
        let inProgress = app.songs.filter { let p = app.songProgress($0.id); return !p.completedSteps.isEmpty && p.fraction(of: $0.steps) < 1 }
        if let recent = inProgress.max(by: { (app.songProgress($0.id).lastPracticed ?? .distantPast) < (app.songProgress($1.id).lastPracticed ?? .distantPast) }) { return recent }
        return app.songs.first { app.songProgress($0.id).completedSteps.isEmpty }
    }

    static func levelName(_ level: Int) -> String {
        ["Consolidate", "Broken chords and dotted rhythms", "Independent hands begin", "Even figuration, melody on top", "Leaps and faster passages", "Early intermediate"][max(0, min(level - 1, 5))]
    }
}

struct SongRow: View {
    @EnvironmentObject private var app: AppModel
    let song: SongEntry
    let highlight: Bool

    var body: some View {
        let progress = app.songProgress(song.id)
        let fraction = progress.fraction(of: song.steps)
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 5)
                Circle().trim(from: 0, to: fraction).stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                if fraction >= 1 { Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(.green) }
                else { Text("L\(song.level)").font(.footnote.weight(.semibold)) }
            }
            .frame(width: 40, height: 40)
            .accessibilityLabel("Level \(song.level), \(Int(fraction * 100)) percent learned")
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(song.title).font(.headline)
                    if song.origin == .imported { Text("Imported").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue.opacity(0.15), in: Capsule()) }
                    if song.levelIsEstimated { Text("Level estimated").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Color.orange.opacity(0.18), in: Capsule()) }
                    if !song.score.warnings.isEmpty { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).accessibilityLabel("Has import notes") }
                }
                if !song.composer.isEmpty { Text(song.composer).font(.subheadline).foregroundStyle(.secondary) }
                if !song.difficulty.topReasons.isEmpty {
                    Text("What makes it hard: " + song.difficulty.topReasons.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if highlight, let next = progress.nextStep(in: song.steps) { Text(next.title).font(.caption).foregroundStyle(.blue) }
        }
        .padding(.vertical, 4)
    }
}

/// One song: what it teaches, its steps, and related lessons.
struct SongDetailView: View {
    @EnvironmentObject private var app: AppModel
    let song: SongEntry

    var body: some View {
        let progress = app.songProgress(song.id)
        List {
            Section {
                if !song.about.isEmpty { Text(song.about) }
                LabeledContent("Level", value: "\(song.level)\(song.levelIsEstimated ? " (estimated from the notes)" : "")")
                LabeledContent("Key", value: Theory.keyName(fifths: song.score.measures.first?.keyFifths ?? 0, minor: song.score.measures.first?.minor ?? false))
                LabeledContent("Tempo", value: "♩ = \(song.score.baseTempo)")
                if !song.difficulty.topReasons.isEmpty {
                    LabeledContent("What makes it hard", value: song.difficulty.topReasons.joined(separator: "; "))
                }
                if song.reviewState == .draft && song.origin == .bundled {
                    Label("Written out for this app and not yet checked against a printed edition. If something sounds wrong, trust the edition.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if !song.score.warnings.isEmpty {
                Section("Import notes") {
                    ForEach(song.score.warnings, id: \.self) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle").font(.subheadline)
                    }
                }
            }
            Section {
                ForEach(song.steps) { step in
                    NavigationLink {
                        PracticeView(app: app, song: song, step: step)
                    } label: {
                        HStack {
                            Image(systemName: progress.completedSteps.contains(step.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(progress.completedSteps.contains(step.id) ? Color.green : Color.secondary)
                            VStack(alignment: .leading) {
                                Text(step.title).font(.body.weight(progress.nextStep(in: song.steps)?.id == step.id ? .bold : .regular))
                                Text(step.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: { Text("Learn it step by step") } footer: {
                Text("A step is ticked after a clean run. You can open any step in any order.")
            }
            Section {
                NavigationLink { PracticeView(app: app, song: song) } label: { Label("Free practice", systemImage: "pianokeys") }
            }
            let lessons = app.pack.lessons(for: song)
            if !lessons.isEmpty {
                Section("Lessons that help with this piece") {
                    ForEach(lessons) { lesson in
                        NavigationLink { LessonView(lesson: lesson) } label: {
                            HStack {
                                Image(systemName: (app.progress.lessons[lesson.id]?.completed ?? false) ? "checkmark.circle.fill" : "book")
                                Text(lesson.title)
                            }
                        }
                    }
                }
            }
            if progress.fraction(of: song.steps) > 0.5 {
                Section("How did this piece feel?") {
                    Picker("Difficulty for you", selection: Binding(get: { progress.userRating ?? 0 }, set: { app.rate(song: song, rating: $0) })) {
                        Text("Not rated").tag(0); Text("Too easy").tag(1); Text("Comfortable").tag(2); Text("About right").tag(3); Text("Hard").tag(4); Text("Too hard").tag(5)
                    }
                }
            }
        }
        .navigationTitle(song.title)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ConnectionBadge() } }
    }
}
