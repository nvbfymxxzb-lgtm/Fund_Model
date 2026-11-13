import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import MusicModel

public struct ImportResult: Sendable {
    public var score: Score
    /// The MusicXML text to draw. For imported files this is the original file.
    public var displayXML: String
}

public enum ScoreImportError: Error, Equatable, CustomStringConvertible {
    case tooLarge
    case unsafeContent(String)
    case notMusicXML(String)
    case timewise
    case archive(String)
    case empty

    public var description: String {
        switch self {
        case .tooLarge: return "The file is larger than the 20 MB limit."
        case .unsafeContent(let why): return "The file was rejected for safety: \(why)."
        case .notMusicXML(let why): return "This is not a MusicXML score the app can read: \(why)."
        case .timewise: return "This file uses the 'timewise' MusicXML layout, which is not supported. Export it as partwise MusicXML."
        case .archive(let why): return "The compressed file could not be opened: \(why)."
        case .empty: return "The score has no notes."
        }
    }
}

public enum ScoreImporter {
    public static let maxBytes = 20 * 1024 * 1024
    public static let maxArchiveEntries = 200

    /// Reads a `.musicxml`, `.xml` or `.mxl` file.
    public static func importFile(data: Data, filename: String) throws -> ImportResult {
        guard data.count <= maxBytes else { throw ScoreImportError.tooLarge }
        let bytes = [UInt8](data)
        let isZip = bytes.count > 4 && bytes[0] == 0x50 && bytes[1] == 0x4b
        if isZip || filename.lowercased().hasSuffix(".mxl") {
            let entries: [ZipArchive.Entry]
            do { entries = try ZipArchive.entries(bytes, maxEntries: maxArchiveEntries, maxTotalBytes: maxBytes) }
            catch let f as Inflate.Failure { throw ScoreImportError.archive(f.reason) }
            var rootPath: String? = nil
            if let container = entries.first(where: { $0.name == "META-INF/container.xml" }) {
                let text = String(decoding: container.data, as: UTF8.self)
                if let r = text.range(of: "full-path=\"") {
                    let rest = text[r.upperBound...]
                    if let end = rest.firstIndex(of: "\"") { rootPath = String(rest[..<end]) }
                }
            }
            let entry = entries.first(where: { $0.name == rootPath })
                ?? entries.first(where: { !$0.name.hasPrefix("META-INF") && ($0.name.hasSuffix(".xml") || $0.name.hasSuffix(".musicxml")) })
            guard let entry else { throw ScoreImportError.archive("no score file inside the archive") }
            return try importXML(Data(entry.data), fallbackTitle: title(from: filename))
        }
        return try importXML(data, fallbackTitle: title(from: filename))
    }

    static func title(from filename: String) -> String {
        let base = (filename as NSString).lastPathComponent
        return (base as NSString).deletingPathExtension
    }

    public static func importXML(_ data: Data, fallbackTitle: String = "Untitled") throws -> ImportResult {
        guard data.count <= maxBytes else { throw ScoreImportError.tooLarge }
        let text = String(decoding: data, as: UTF8.self)
        if text.range(of: "<!ENTITY", options: .caseInsensitive) != nil {
            throw ScoreImportError.unsafeContent("it declares XML entities")
        }
        let delegate = MusicXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        let ok = parser.parse()
        if delegate.isTimewise { throw ScoreImportError.timewise }
        guard delegate.sawPartwise else {
            throw ScoreImportError.notMusicXML(ok ? "no <score-partwise> element" : (parser.parserError?.localizedDescription ?? "the XML is malformed"))
        }
        if !ok && delegate.measures.isEmpty { throw ScoreImportError.notMusicXML(parser.parserError?.localizedDescription ?? "the XML is malformed") }
        var score = delegate.finish(fallbackTitle: fallbackTitle)
        guard score.notes.contains(where: { !$0.isGrace }) else { throw ScoreImportError.empty }
        if !ok { score.warnings.append(ScoreWarning(code: "truncated", message: "The file ended unexpectedly; only the readable part was imported.")) }
        return ImportResult(score: score, displayXML: text)
    }
}

final class MusicXMLParserDelegate: NSObject, XMLParserDelegate {
    var sawPartwise = false
    var isTimewise = false
    var partIndex = -1
    var partCount = 0
    var title: String?
    var composer: String?

    var measures: [Measure] = []
    var notes: [ScoreNote] = []
    var warnings: [ScoreWarning] = []
    var unscored: Set<Int> = []
    var warned: Set<String> = []

    // Running state
    var divisions: Int64 = 1
    var time = TimeSignature(beats: 4, beatType: 4)
    var keyFifths = 0
    var minor = false
    var cursor = Rational.zero
    var maxCursor = Rational.zero
    var lastOnset = Rational.zero
    var voiceMap: [String: Int] = [:]
    var eventCount = 0
    var chordIndex = 0
    var activeEndings: [Int] = []
    var endingsStopAfterMeasure = false
    var octaveShiftActive = false
    var current: Measure?
    var stack: [String] = []
    var text = ""

    // Note state
    var inNote = false
    var nRest = false, nChord = false, nGrace = false, nCue = false, nOrnament = false
    var nStep: Step?, nAlter = 0, nOctave = 4
    var nDuration: Int64 = 0
    var nVoice = "1", nStaff = 1
    var nTieStart = false, nTieStop = false
    var nFinger: Int?
    var barlineLocation = "right"
    var pendingDuration: Int64 = 0
    var metronomeUnit: String?

    func warn(_ code: String, _ message: String, measure: Int? = nil, once: Bool = true) {
        if once { if warned.contains(code) { return }; warned.insert(code) }
        warnings.append(ScoreWarning(code: code, message: message, measureIndex: measure))
    }

    var parsingThisPart: Bool { partIndex == 0 }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String] = [:]) {
        stack.append(name)
        text = ""
        switch name {
        case "score-partwise": sawPartwise = true
        case "score-timewise": isTimewise = true; parser.abortParsing()
        case "part":
            partIndex += 1; partCount += 1
            if partIndex == 1 { warn("multiplePart", "The file has more than one part. Only the first part was imported.") }
        default: break
        }
        guard parsingThisPart else { return }
        switch name {
        case "measure":
            let index = measures.count
            var m = Measure(index: index, number: a["number"] ?? "\(index + 1)", length: time.length, time: time, keyFifths: keyFifths, minor: minor)
            m.isPickup = a["implicit"] == "yes" && index == 0
            m.endings = activeEndings
            current = m
            cursor = .zero; maxCursor = .zero; lastOnset = .zero; eventCount = 0
        case "note":
            inNote = true
            nRest = false; nChord = false; nGrace = false; nCue = false; nOrnament = false
            nStep = nil; nAlter = 0; nOctave = 4; nDuration = 0; nVoice = "1"; nStaff = 1
            nTieStart = false; nTieStop = false; nFinger = nil
        case "rest": if inNote { nRest = true }
        case "chord": if inNote { nChord = true }
        case "grace": if inNote { nGrace = true }
        case "cue": if inNote { nCue = true }
        case "tie":
            if inNote { if a["type"] == "start" { nTieStart = true } else if a["type"] == "stop" { nTieStop = true } }
        case "ornaments", "tremolo", "arpeggiate", "glissando", "slide":
            if inNote { nOrnament = true }
        case "barline": barlineLocation = a["location"] ?? "right"
        case "repeat":
            if a["direction"] == "forward" { current?.repeatStart = true } else if a["direction"] == "backward" { current?.repeatEnd = true }
        case "ending":
            let numbers = (a["number"] ?? "").split(whereSeparator: { $0 == "," || $0 == " " }).compactMap { Int($0) }
            if a["type"] == "start" {
                activeEndings = numbers
                current?.endings = numbers
            } else {
                endingsStopAfterMeasure = true
            }
        case "sound":
            if let t = a["tempo"], let bpm = Double(t), bpm > 0, current?.tempoBPM == nil { current?.tempoBPM = Int(bpm.rounded()) }
            for jump in ["dacapo", "segno", "dalsegno", "coda", "tocoda", "fine"] where a[jump] != nil {
                warn("jumps", "The score has jumps (D.C., D.S., Coda or Fine). They are not followed; the music is played straight through.", measure: current?.index)
            }
        case "octave-shift":
            let type = a["type"] ?? ""
            if type == "stop" { octaveShiftActive = false } else {
                octaveShiftActive = true
                if let i = current?.index { unscored.insert(i) }
                warn("octaveShift", "The score uses 8va/8vb marks. Those measures are shown but not graded.", measure: current?.index)
            }
        case "transpose":
            warn("transpose", "The part is for a transposing instrument. Pitches may not match what a piano should play.")
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        defer { stack.removeLast(); text = "" }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = stack.count >= 2 ? stack[stack.count - 2] : ""
        if name == "work-title" || (name == "movement-title" && title == nil) { if !value.isEmpty { title = value } }
        if name == "creator" && composer == nil && !value.isEmpty { composer = value }
        guard parsingThisPart else { return }
        switch name {
        case "divisions": if let v = Int64(value), v > 0 { divisions = v }
        case "fifths": if let v = Int(value) { keyFifths = v; if cursor == .zero { current?.keyFifths = v } }
        case "mode": minor = value == "minor"; if cursor == .zero { current?.minor = minor }
        case "beats":
            if parent == "time", let v = Int(value.split(separator: "+").first ?? "") { time.beats = v }
        case "beat-type":
            if parent == "time", let v = Int(value), v > 0 {
                time.beatType = v
                current?.time = time
            }
        case "step": if inNote { nStep = value.first.flatMap { Step(letter: $0) } }
        case "alter": if inNote { nAlter = Int(Double(value) ?? 0) }
        case "octave": if inNote { nOctave = Int(value) ?? 4 }
        case "duration":
            if inNote { nDuration = Int64(value) ?? 0 } else { pendingDuration = Int64(value) ?? 0 }
        case "voice": if inNote { nVoice = value }
        case "staff": if inNote { nStaff = Int(value) ?? 1 }
        case "fingering": if inNote { nFinger = Int(value) }
        case "beat-unit": metronomeUnit = value
        case "per-minute":
            if let bpm = Double(value), bpm > 0, current?.tempoBPM == nil {
                let factor: Double
                switch metronomeUnit ?? "quarter" {
                case "half": factor = 2
                case "eighth": factor = 0.5
                case "whole": factor = 4
                default: factor = 1
                }
                current?.tempoBPM = Int((bpm * factor).rounded())
            }
        case "backup":
            cursor = cursor - Rational(pendingDuration, 4 * divisions)
            if cursor < .zero { cursor = .zero }
        case "forward":
            cursor += Rational(pendingDuration, 4 * divisions)
            if cursor > maxCursor { maxCursor = cursor }
        case "note":
            inNote = false
            finishNote()
        case "measure":
            finishMeasure()
        default: break
        }
    }

    func finishNote() {
        guard var m = current, !nCue else { return }
        defer { current = m }
        if nGrace {
            unscored.insert(m.index)
            warn("grace", "The score has grace notes. Those measures are shown but not graded.", measure: m.index)
            if let step = nStep, !nRest {
                let pitch = SpelledPitch(step: step, alter: nAlter, octave: nOctave)
                notes.append(ScoreNote(id: "m\(m.index).g\(notes.count)", measureIndex: m.index, staff: nStaff, voice: 1, pitch: pitch,
                                       onset: cursor, duration: .zero, isGrace: true, hand: nStaff == 1 ? .right : .left))
            }
            return
        }
        let duration = Rational(nDuration, 4 * divisions)
        let onset: Rational
        if nChord { onset = lastOnset; chordIndex += 1 } else {
            onset = cursor; cursor += duration; lastOnset = onset; chordIndex = 0; eventCount += 1
            if cursor > maxCursor { maxCursor = cursor }
        }
        guard !nRest, let step = nStep else { return }
        if octaveShiftActive { unscored.insert(m.index) }
        if nOrnament {
            unscored.insert(m.index)
            warn("ornament", "The score has ornaments, tremolos or rolled chords. Those measures are shown but not graded.", measure: m.index)
        }
        let voiceKey = "\(nStaff)|\(nVoice)"
        if voiceMap[voiceKey] == nil {
            voiceMap[voiceKey] = voiceMap.keys.filter { $0.hasPrefix("\(nStaff)|") }.count + 1
        }
        let voice = voiceMap[voiceKey]!
        if voice > 2 { warn("voices", "A staff has more than two voices. All notes are imported, but the display may be crowded.") }
        let tie: TieRole? = nTieStart && nTieStop ? .continue : (nTieStart ? .start : (nTieStop ? .stop : nil))
        let pitch = SpelledPitch(step: step, alter: nAlter, octave: nOctave)
        notes.append(ScoreNote(id: "m\(m.index).s\(nStaff).v\(voice).e\(eventCount).p\(chordIndex)", measureIndex: m.index, staff: nStaff,
                               voice: voice, pitch: pitch, onset: onset, duration: duration, tie: tie,
                               hand: nStaff == 1 ? .right : .left, finger: nFinger))
    }

    func finishMeasure() {
        guard var m = current else { return }
        m.time = time
        if maxCursor > .zero { m.length = maxCursor } else { m.length = time.length }
        if m.index == 0 && m.length < time.length { m.isPickup = true }
        if !m.isPickup && m.length > time.length * Rational(2, 1) {
            warn("longMeasure", "A measure is much longer than its time signature. The file may be damaged.", measure: m.index)
        }
        measures.append(m)
        current = nil
        if endingsStopAfterMeasure { activeEndings = []; endingsStopAfterMeasure = false }
    }

    func finish(fallbackTitle: String) -> Score {
        if partCount > 1 { warn("multiplePart", "The file has more than one part. Only the first part was imported.") }
        if !measures.contains(where: { $0.tempoBPM != nil }) {
            warn("noTempo", "The score gives no tempo. The app uses \(Score.defaultTempoBPM) beats per minute.")
        }
        if measures.contains(where: { $0.endings.contains(where: { $0 > 2 }) }) {
            warn("endings", "The score has third or later endings. Only first and second endings are followed.")
        }
        return Score(title: title ?? fallbackTitle, composer: composer ?? "", measures: measures, notes: notes,
                     warnings: warnings, unscoredMeasures: unscored)
    }
}
