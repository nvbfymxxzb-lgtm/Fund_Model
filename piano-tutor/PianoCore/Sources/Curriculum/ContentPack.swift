import Foundation
import MusicModel
import ScoreImport
import PracticeEngine
import Difficulty
import TheoryKit

public struct ContentProblem: Hashable, Sendable, CustomStringConvertible {
    public var file: String
    public var message: String
    public var description: String { "\(file): \(message)" }
}

/// The songs and lessons shipped with the app.
public struct ContentPack: Sendable {
    public var skills: [Skill]
    public var units: [Unit]
    public var songs: [SongEntry]
    public var problems: [ContentProblem]

    public static var bundledURL: URL? { Bundle.module.resourceURL?.appendingPathComponent("Content") }

    public static func loadBundled() -> ContentPack { load(from: bundledURL) }

    public static func load(from root: URL?) -> ContentPack {
        var pack = ContentPack(skills: [], units: [], songs: [], problems: [])
        guard let root else { pack.problems.append(ContentProblem(file: "Content", message: "content folder not found")); return pack }
        let fm = FileManager.default
        let decoder = JSONDecoder()

        if let data = try? Data(contentsOf: root.appendingPathComponent("skills.json")) {
            do { pack.skills = try decoder.decode([Skill].self, from: data) }
            catch { pack.problems.append(ContentProblem(file: "skills.json", message: "\(error)")) }
        }

        func jsonFiles(_ folder: String) -> [URL] {
            ((try? fm.contentsOfDirectory(at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        for url in jsonFiles("lessons") {
            do { pack.units.append(try decoder.decode(Unit.self, from: Data(contentsOf: url))) }
            catch { pack.problems.append(ContentProblem(file: url.lastPathComponent, message: "\(error)")) }
        }
        pack.units.sort { ($0.track.rawValue, $0.order) < ($1.track.rawValue, $1.order) }

        for url in jsonFiles("songs") {
            do {
                let file = try decoder.decode(SongFile.self, from: Data(contentsOf: url))
                let score = try TinyNotation.parse(file.source)
                let phrases = file.phrases?.compactMap { $0.count == 2 && $0[0] <= $0[1] ? $0[0]...$0[1] : nil }
                pack.songs.append(SongEntry(id: file.id, origin: .bundled, level: file.level, about: file.about, skillIds: file.skillIds,
                                            reviewState: file.reviewState, score: score, phrases: phrases))
            } catch { pack.problems.append(ContentProblem(file: url.lastPathComponent, message: "\(error)")) }
        }
        pack.songs = ContentPack.ranked(pack.songs)
        pack.problems.append(contentsOf: pack.validate())
        return pack
    }

    /// Songs in learning order: by level, then by measured difficulty within a level.
    public static func ranked(_ songs: [SongEntry]) -> [SongEntry] {
        songs.sorted { ($0.level, $0.difficulty.score, $0.title) < ($1.level, $1.difficulty.score, $1.title) }
    }

    public var lessons: [Lesson] { units.flatMap { $0.lessons } }
    public func units(in track: Track) -> [Unit] { units.filter { $0.track == track }.sorted { $0.order < $1.order } }
    public func lesson(_ id: String) -> Lesson? { lessons.first { $0.id == id } }
    public func skill(_ id: String) -> Skill? { skills.first { $0.id == id } }

    /// Lessons that teach a skill a song uses.
    public func lessons(for song: SongEntry) -> [Lesson] {
        lessons.filter { !Set($0.skillIds).isDisjoint(with: song.skillIds) }
    }
    /// Songs that use a skill a lesson teaches, easiest first.
    public func songs(for lesson: Lesson) -> [SongEntry] {
        songs.filter { !Set($0.skillIds).isDisjoint(with: lesson.skillIds) }
    }

    /// Checks that everything in the pack refers to things that exist and that every question has a valid answer.
    public func validate() -> [ContentProblem] {
        var problems: [ContentProblem] = []
        let skillIds = Set(skills.map { $0.id })
        let songIds = Set(songs.map { $0.id })
        var seen: Set<String> = []
        for s in skills {
            for p in s.prerequisites where !skillIds.contains(p) { problems.append(ContentProblem(file: "skills.json", message: "\(s.id) needs unknown skill \(p)")) }
        }
        for song in songs {
            if !seen.insert("song:" + song.id).inserted { problems.append(ContentProblem(file: song.id, message: "duplicate song id")) }
            for id in song.skillIds where !skillIds.contains(id) { problems.append(ContentProblem(file: song.id, message: "unknown skill \(id)")) }
            if !(1...6).contains(song.level) { problems.append(ContentProblem(file: song.id, message: "level must be 1–6")) }
        }
        for unit in units {
            for lesson in unit.lessons {
                if !seen.insert("lesson:" + lesson.id).inserted { problems.append(ContentProblem(file: unit.id, message: "duplicate lesson id \(lesson.id)")) }
                for id in lesson.skillIds where !skillIds.contains(id) { problems.append(ContentProblem(file: lesson.id, message: "unknown skill \(id)")) }
                for (i, block) in lesson.blocks.enumerated() {
                    let place = "\(lesson.id) block \(i + 1)"
                    switch block.type {
                    case .text: if (block.text ?? "").isEmpty { problems.append(ContentProblem(file: place, message: "empty text")) }
                    case .keyboard: if (block.keys ?? []).isEmpty { problems.append(ContentProblem(file: place, message: "keyboard with no keys")) }
                    case .scale:
                        if NoteName(block.scaleTonic ?? "") == nil || block.scaleType == nil { problems.append(ContentProblem(file: place, message: "scale needs a tonic and type")) }
                    case .chords, .listen:
                        if (block.chords ?? []).isEmpty && (block.keys ?? []).isEmpty { problems.append(ContentProblem(file: place, message: "nothing to show or play")) }
                        for c in block.chords ?? [] where NoteName(c.root) == nil { problems.append(ContentProblem(file: place, message: "bad chord root \(c.root)")) }
                    case .exercise:
                        guard let e = block.exercise else { problems.append(ContentProblem(file: place, message: "missing exercise")); continue }
                        problems.append(contentsOf: ContentPack.check(e).map { ContentProblem(file: place, message: $0) })
                    case .generated:
                        guard let g = block.generator else { problems.append(ContentProblem(file: place, message: "missing generator")); continue }
                        let made = ExerciseGenerator.make(g, seed: 1)
                        if made.count < g.count { problems.append(ContentProblem(file: place, message: "generator made \(made.count) of \(g.count) questions")) }
                        for e in made { problems.append(contentsOf: ContentPack.check(e).map { ContentProblem(file: place, message: $0) }) }
                    case .songLink:
                        if !songIds.contains(block.songId ?? "") { problems.append(ContentProblem(file: place, message: "unknown song \(block.songId ?? "")")) }
                    case .checklist: if (block.items ?? []).isEmpty { problems.append(ContentProblem(file: place, message: "empty checklist")) }
                    }
                }
            }
        }
        return problems
    }

    static func check(_ e: Exercise) -> [String] {
        var out: [String] = []
        switch e.kind {
        case .choice, .earInterval, .earChord:
            guard let options = e.options, let answer = e.answer, options.indices.contains(answer) else { return ["\(e.id): needs options and a valid answer"] }
            if Set(options).count != options.count { out.append("\(e.id): repeated options") }
            if e.kind == .earInterval && (e.rootMidi == nil || e.semitones == nil) { out.append("\(e.id): needs notes to play") }
            if e.kind == .earChord && e.chord == nil { out.append("\(e.id): needs a chord to play") }
        case .playChord:
            if e.chord == nil || NoteName(e.chord!.root) == nil { out.append("\(e.id): needs a valid chord") }
        case .playProgression:
            if (e.chords ?? []).isEmpty { out.append("\(e.id): needs chords") }
        case .playScale:
            if NoteName(e.scaleTonic ?? "") == nil || e.scaleType == nil { out.append("\(e.id): needs a scale") }
        case .playInterval:
            if e.rootMidi == nil || e.semitones == nil { out.append("\(e.id): needs a start note and size") }
        }
        return out
    }
}

/// Songs the learner has imported, kept as files in the app's own folder.
public struct ImportedSongStore: Sendable {
    public var folder: URL
    public init(folder: URL) { self.folder = folder }

    struct Record: Codable { var id: String; var filename: String; var importedAt: Date }

    public func add(data: Data, filename: String) throws -> SongEntry {
        let result = try ScoreImporter.importFile(data: data, filename: filename)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let id = "import-" + UUID().uuidString.prefix(8).lowercased()
        // Keep the readable XML (already unpacked if the file was compressed) and never the original path.
        try Data(result.displayXML.utf8).write(to: folder.appendingPathComponent("\(id).musicxml"), options: .atomic)
        return SongEntry(id: id, origin: .imported, about: "Imported from \((filename as NSString).lastPathComponent).", score: result.score, displayXML: result.displayXML)
    }

    public func loadAll() -> [SongEntry] {
        let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "musicxml" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url), let r = try? ScoreImporter.importXML(data, fallbackTitle: "Imported song") else { return nil }
            return SongEntry(id: url.deletingPathExtension().lastPathComponent, origin: .imported, about: "Imported score.", score: r.score, displayXML: r.displayXML)
        }
    }

    public func delete(id: String) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("\(id).musicxml"))
    }
}
