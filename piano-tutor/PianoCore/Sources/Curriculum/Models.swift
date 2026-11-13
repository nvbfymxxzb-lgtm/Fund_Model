import Foundation
import MusicModel
import PracticeEngine
import Difficulty
import TheoryKit

public enum Track: String, Codable, Sendable, CaseIterable {
    case pianoTechnique, musicTheory
    public var title: String { self == .pianoTechnique ? "Piano technique & theory" : "Music theory" }
}

/// How far a piece of content has been checked. Nothing in this pack has been reviewed by a teacher.
public enum ReviewState: String, Codable, Sendable {
    case draft          // written, not yet checked against sources
    case crossChecked   // checked against references and by automated tests
    case published
}

public struct Skill: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var track: Track
    public var title: String
    public var prerequisites: [String]
}

public enum BlockType: String, Codable, Sendable {
    case text, keyboard, scale, chords, listen, exercise, generated, songLink, checklist
}

/// One piece of a lesson: some explanation, a picture, something to hear, or a question.
public struct LessonBlock: Codable, Hashable, Sendable {
    public var type: BlockType
    public var text: String?
    /// MIDI notes to light up on a keyboard picture.
    public var keys: [Int]?
    public var labels: [String]?
    public var scaleTonic: String?
    public var scaleType: ScaleType?
    public var hand: HandSelection?
    public var chords: [ChordSpec]?
    public var chordLabels: [String]?
    public var exercise: Exercise?
    public var generator: GeneratorSpec?
    public var songId: String?
    public var items: [String]?
}

public struct Lesson: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var minutes: Int
    public var skillIds: [String]
    public var reviewState: ReviewState
    public var sources: [String]?
    public var blocks: [LessonBlock]
}

public struct Unit: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var track: Track
    public var order: Int
    public var title: String
    public var summary: String
    public var lessons: [Lesson]
}

/// A bundled song with what the app knows about it.
public struct SongFile: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var level: Int
    /// Where the level comes from, such as a published syllabus grade. Nil means the level is the author's estimate.
    public var levelAnchor: String?
    public var about: String
    public var skillIds: [String]
    public var reviewState: ReviewState
    public var rights: String
    /// Phrase boundaries as [first, last] measure indexes. Nil lets the app split the piece itself.
    public var phrases: [[Int]]?
    public var source: SongSource
}

public enum SongOrigin: String, Codable, Sendable { case bundled, imported }

/// A song ready to show in the library.
public struct SongEntry: Identifiable, Sendable {
    public var id: String
    public var origin: SongOrigin
    public var title: String
    public var composer: String
    public var level: Int
    public var levelIsEstimated: Bool
    public var about: String
    public var skillIds: [String]
    public var reviewState: ReviewState
    public var score: Score
    public var displayXML: String
    public var difficulty: DifficultyReport
    public var steps: [LearningStep]

    public init(id: String, origin: SongOrigin, level: Int? = nil, about: String = "", skillIds: [String] = [],
                reviewState: ReviewState = .draft, score: Score, displayXML: String? = nil, phrases: [ClosedRange<Int>]? = nil) {
        let report = DifficultyAnalyzer.analyze(score)
        self.id = id; self.origin = origin; self.title = score.title; self.composer = score.composer
        self.level = level ?? report.estimatedLevel
        self.levelIsEstimated = level == nil
        self.about = about; self.skillIds = skillIds; self.reviewState = reviewState
        self.score = score
        self.displayXML = displayXML ?? MusicXMLWriter.write(score)
        self.difficulty = report
        self.steps = LearningPath.generate(score: score, phrases: phrases, troubleSpots: report.hardestWindows)
    }
}

/// Progress on one skill, with a simple spaced-review schedule.
public struct SkillProgress: Codable, Hashable, Sendable {
    public static let intervalsInDays = [1, 3, 7, 14, 30]
    public var skillId: String
    public var box: Int = 0
    public var correct: Int = 0
    public var incorrect: Int = 0
    public var nextReview: Date?

    public init(skillId: String) { self.skillId = skillId }

    public var isSecure: Bool { box >= 3 }

    public mutating func record(success: Bool, now: Date = Date()) {
        if success { correct += 1; box = min(box + 1, SkillProgress.intervalsInDays.count) }
        else { incorrect += 1; box = max(box - 1, 0) }
        let days = SkillProgress.intervalsInDays[max(0, min(box, SkillProgress.intervalsInDays.count) - 1)]
        nextReview = now.addingTimeInterval(Double(days) * 86_400)
    }
    public func isDue(now: Date = Date()) -> Bool { nextReview.map { $0 <= now } ?? false }
}

public struct LessonProgress: Codable, Hashable, Sendable {
    public var completed: Bool = false
    public var bestScore: Double = 0
    public var lastOpened: Date?
    public init() {}
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var strictChords = true
    public var calibrationOffsetMs = 0
    public var demoThroughPiano = true
    public var metronomeOn = true
    public var showNoteNames = false
    public var accompanyOtherHand = true
    public var keyTouchNote = ""
    public init() {}
}

/// Everything the app remembers about the learner. Saved as one JSON file.
public struct AppProgress: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion = AppProgress.currentSchemaVersion
    public var songs: [String: SongProgress] = [:]
    public var lessons: [String: LessonProgress] = [:]
    public var skills: [String: SkillProgress] = [:]
    public var settings = AppSettings()
    public var practiceSeconds: Double = 0
    public var techniqueHistory: [TechniqueSample] = []

    public init() {}

    public struct TechniqueSample: Codable, Hashable, Sendable {
        public var date: Date
        public var songId: String
        public var timingSpreadMs: Double?
        public var velocitySpread: Double?
        public var legatoShare: Double?
        public var handBalance: Double?
        public init(date: Date, songId: String, report: TechniqueReport) {
            self.date = date; self.songId = songId; timingSpreadMs = report.timingSpreadMs
            velocitySpread = report.velocitySpread; legatoShare = report.legatoShare; handBalance = report.handBalance
        }
    }

    public mutating func record(skills ids: [String], success: Bool, now: Date = Date()) {
        for id in ids {
            var p = skills[id] ?? SkillProgress(skillId: id)
            p.record(success: success, now: now)
            skills[id] = p
        }
    }
}

public enum ProgressStore {
    public static func load(from url: URL) -> AppProgress {
        guard let data = try? Data(contentsOf: url) else { return AppProgress() }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        // A file that cannot be read is kept aside rather than overwritten.
        guard let progress = try? d.decode(AppProgress.self, from: data) else {
            try? data.write(to: url.appendingPathExtension("unreadable"))
            return AppProgress()
        }
        return progress
    }

    public static func save(_ progress: AppProgress, to url: URL) throws {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try e.encode(progress).write(to: url, options: .atomic)
    }
}
