import Foundation
import MusicModel
import ScoreImport
import PracticeEngine
import Difficulty
import Curriculum

// A small command-line helper for checking content without the iPad.
//   pianotool rank                 list bundled songs in learning order with their difficulty
//   pianotool export-xml <folder>  write each bundled song as MusicXML
//   pianotool check <file>         import a MusicXML/MXL file and report what the app makes of it
//   pianotool grade <song-id> <trace.jsonl>   grade a recorded performance

let args = Array(CommandLine.arguments.dropFirst())
let pack = ContentPack.loadBundled()

func describe(_ song: SongEntry) -> String {
    let level = song.levelIsEstimated ? "L\(song.level) (estimated)" : "L\(song.level)"
    return "\(level)  \(String(format: "%5.1f", song.difficulty.score))  \(song.title) — \(song.difficulty.topReasons.joined(separator: "; "))"
}

switch args.first {
case "rank":
    for p in pack.problems { print("PROBLEM: \(p)") }
    for s in pack.songs { print(describe(s)) }
case "export-xml":
    guard args.count > 1 else { print("usage: pianotool export-xml <folder>"); exit(2) }
    let folder = URL(fileURLWithPath: args[1])
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for s in pack.songs {
        try Data(s.displayXML.utf8).write(to: folder.appendingPathComponent("\(s.id).musicxml"))
        let keys = s.score.timeline(passage: s.score.wholePassage).attacks.map { $0.matchKey }
        try JSONEncoder().encode(Array(Set(keys)).sorted()).write(to: folder.appendingPathComponent("\(s.id).keys.json"))
    }
    print("wrote \(pack.songs.count) songs to \(folder.path)")
case "check":
    guard args.count > 1 else { print("usage: pianotool check <file>"); exit(2) }
    let url = URL(fileURLWithPath: args[1])
    do {
        let result = try ScoreImporter.importFile(data: try Data(contentsOf: url), filename: url.lastPathComponent)
        let entry = SongEntry(id: "check", origin: .imported, score: result.score, displayXML: result.displayXML)
        print(describe(entry))
        print("\(result.score.measures.count) measures, \(result.score.notes.count) notes, tempo \(result.score.baseTempo)")
        for w in result.score.warnings { print("warning: \(w.message)") }
        if !result.score.unscoredMeasures.isEmpty { print("not graded: measures \(result.score.unscoredMeasures.sorted().map { result.score.measures[$0].number }.joined(separator: ", "))") }
    } catch { print("could not import: \(error)"); exit(1) }
case "grade":
    guard args.count > 2, let song = pack.songs.first(where: { $0.id == args[1] }) else { print("usage: pianotool grade <song-id> <trace.jsonl>"); exit(2) }
    let trace = try PerformanceTrace(jsonLines: String(contentsOf: URL(fileURLWithPath: args[2]), encoding: .utf8))
    let timeline = song.score.timeline(passage: trace.header.passage, tempoPercent: trace.header.tempoPercent)
    var tolerances = Tolerances(); tolerances.calibrationOffsetUs = trace.header.calibrationOffsetUs
    let report: AttemptReport
    if trace.header.mode == .wait {
        var session = WaitModeSession(timeline: timeline, hand: trace.header.hand, tolerances: tolerances)
        for e in trace.events { _ = session.handle(e) }
        report = session.report()
    } else {
        report = RhythmEvaluator.evaluate(timeline: timeline, hand: trace.header.hand, events: trace.events, tolerances: tolerances)
    }
    print("result: \(report.result.rawValue)  matched \(report.matchedCount)/\(report.scoredCount)  missed \(report.missedCount)  wrong \(report.wrongCount)  extra \(report.extraCount)  not graded \(report.excludedCount)")
    let technique = TechniqueMetrics.measure(timeline: timeline, report: report, events: trace.events)
    if let t = technique.timingSpreadMs { print(String(format: "timing spread %.1f ms", t)) }
    if let l = technique.legatoShare { print(String(format: "legato joins %.0f%%", l * 100)) }
default:
    print("usage: pianotool rank | export-xml <folder> | check <file> | grade <song-id> <trace.jsonl>")
}
