import Foundation

/// Writes a score as MusicXML so the notation view can draw it.
public enum MusicXMLWriter {
    static let divisions: Int64 = 96   // per quarter note

    static let noteTypes: [(Rational, String, Int, Bool)] = [
        (Rational(3, 2), "whole", 1, false), (Rational(1, 1), "whole", 0, false),
        (Rational(3, 4), "half", 1, false), (Rational(1, 2), "half", 0, false),
        (Rational(3, 8), "quarter", 1, false), (Rational(1, 4), "quarter", 0, false),
        (Rational(3, 16), "eighth", 1, false), (Rational(1, 8), "eighth", 0, false),
        (Rational(3, 32), "16th", 1, false), (Rational(1, 16), "16th", 0, false),
        (Rational(1, 32), "32nd", 0, false),
        (Rational(1, 3), "half", 0, true), (Rational(1, 6), "quarter", 0, true),
        (Rational(1, 12), "eighth", 0, true), (Rational(1, 24), "16th", 0, true),
    ]

    static func typeXML(_ duration: Rational) -> String {
        guard let t = noteTypes.first(where: { $0.0 == duration }) else { return "" }
        var s = "<type>\(t.1)</type>" + String(repeating: "<dot/>", count: t.2)
        if t.3 { s += "<time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>" }
        return s
    }

    static func units(_ duration: Rational) -> Int64 { (duration * Rational(4 * divisions, 1)).rounded }

    /// Splits a silent gap into rest lengths that can be drawn.
    static func restPieces(_ gap: Rational) -> [Rational] {
        var remaining = gap
        var pieces: [Rational] = []
        let plain = noteTypes.filter { !$0.3 }.map { $0.0 }.sorted(by: >)
        let all = noteTypes.map { $0.0 }.sorted(by: >)
        var guardCount = 0
        while remaining > .zero && guardCount < 64 {
            guardCount += 1
            if let p = plain.first(where: { $0 <= remaining && (remaining - $0).d % 3 != 0 || $0 == remaining }) ?? all.first(where: { $0 <= remaining }) {
                pieces.append(p); remaining = remaining - p
            } else {
                pieces.append(remaining); remaining = .zero
            }
        }
        return pieces
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    public static func write(_ score: Score, showFingering: Bool = true, singleStaff: Bool = false) -> String {
        var x = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<score-partwise version=\"4.0\">\n"
        x += "<work><work-title>\(escape(score.title))</work-title></work>\n"
        if !score.composer.isEmpty {
            x += "<identification><creator type=\"composer\">\(escape(score.composer))</creator></identification>\n"
        }
        x += "<part-list><score-part id=\"P1\"><part-name>Piano</part-name></score-part></part-list>\n<part id=\"P1\">\n"
        let byMeasure = Dictionary(grouping: score.notes, by: { $0.measureIndex })
        let staves = singleStaff ? [1] : [1, 2]
        var previous: Measure? = nil

        for m in score.measures {
            x += "<measure number=\"\(escape(m.number))\"\(m.isPickup ? " implicit=\"yes\"" : "")>\n"
            var attributes = ""
            if previous == nil { attributes += "<divisions>\(divisions)</divisions>" }
            if previous == nil || previous!.keyFifths != m.keyFifths || previous!.minor != m.minor {
                attributes += "<key><fifths>\(m.keyFifths)</fifths><mode>\(m.minor ? "minor" : "major")</mode></key>"
            }
            if previous == nil || previous!.time != m.time {
                attributes += "<time><beats>\(m.time.beats)</beats><beat-type>\(m.time.beatType)</beat-type></time>"
            }
            if previous == nil {
                if singleStaff {
                    let low = score.notes.map { $0.midi }.min() ?? 60
                    attributes += low < 55 ? "<clef><sign>F</sign><line>4</line></clef>" : "<clef><sign>G</sign><line>2</line></clef>"
                } else {
                    attributes += "<staves>2</staves><clef number=\"1\"><sign>G</sign><line>2</line></clef><clef number=\"2\"><sign>F</sign><line>4</line></clef>"
                }
            }
            if !attributes.isEmpty { x += "<attributes>\(attributes)</attributes>\n" }
            if let bpm = m.tempoBPM {
                x += "<direction placement=\"above\"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>\(bpm)</per-minute></metronome></direction-type><staff>1</staff><sound tempo=\"\(bpm)\"/></direction>\n"
            }
            if m.repeatStart || !m.endings.isEmpty {
                x += "<barline location=\"left\">"
                if m.repeatStart { x += "<bar-style>heavy-light</bar-style>" }
                if !m.endings.isEmpty { x += "<ending number=\"\(m.endings.map(String.init).joined(separator: ","))\" type=\"start\"/>" }
                if m.repeatStart { x += "<repeat direction=\"forward\"/>" }
                x += "</barline>\n"
            }

            let notes = byMeasure[m.index] ?? []
            var wroteVoice = false
            for staff in staves {
                let staffNotes = singleStaff ? notes : notes.filter { $0.staff == staff }
                var voices = Array(Set(staffNotes.map { $0.voice })).sorted()
                if voices.isEmpty { voices = [1] }
                for voice in voices {
                    if wroteVoice { x += "<backup><duration>\(units(m.length))</duration></backup>\n" }
                    wroteVoice = true
                    let xmlVoice = (staff - 1) * 4 + voice
                    let voiceNotes = staffNotes.filter { $0.voice == voice && !$0.isGrace }
                    if voiceNotes.isEmpty {
                        x += "<note><rest measure=\"yes\"/><duration>\(units(m.length))</duration><voice>\(xmlVoice)</voice><staff>\(staff)</staff></note>\n"
                        continue
                    }
                    var cursor = Rational.zero
                    let onsets = Array(Set(voiceNotes.map { $0.onset })).sorted()
                    func rest(_ gap: Rational) {
                        for piece in restPieces(gap) {
                            x += "<note><rest/><duration>\(units(piece))</duration><voice>\(xmlVoice)</voice>\(typeXML(piece))<staff>\(staff)</staff></note>\n"
                        }
                    }
                    for onset in onsets {
                        if onset > cursor { rest(onset - cursor) }
                        let chord = voiceNotes.filter { $0.onset == onset }.sorted { $0.midi < $1.midi }
                        for (i, n) in chord.enumerated() {
                            x += "<note>"
                            if i > 0 { x += "<chord/>" }
                            x += "<pitch><step>\(n.pitch.step.letter)</step>"
                            if n.pitch.alter != 0 { x += "<alter>\(n.pitch.alter)</alter>" }
                            x += "<octave>\(n.pitch.octave)</octave></pitch><duration>\(units(n.duration))</duration>"
                            if n.tie == .stop || n.tie == .continue { x += "<tie type=\"stop\"/>" }
                            if n.tie == .start || n.tie == .continue { x += "<tie type=\"start\"/>" }
                            x += "<voice>\(xmlVoice)</voice>\(typeXML(n.duration))<staff>\(singleStaff ? 1 : n.staff)</staff>"
                            var notations = ""
                            if n.tie == .stop || n.tie == .continue { notations += "<tied type=\"stop\"/>" }
                            if n.tie == .start || n.tie == .continue { notations += "<tied type=\"start\"/>" }
                            if showFingering, let f = n.finger { notations += "<technical><fingering>\(f)</fingering></technical>" }
                            if !notations.isEmpty { x += "<notations>\(notations)</notations>" }
                            x += "</note>\n"
                        }
                        cursor = onset + (chord.map { $0.duration }.min() ?? .zero)
                    }
                    if cursor < m.length { rest(m.length - cursor) }
                }
            }
            if m.repeatEnd || !m.endings.isEmpty {
                x += "<barline location=\"right\">"
                if m.repeatEnd { x += "<bar-style>light-heavy</bar-style>" }
                if !m.endings.isEmpty { x += "<ending number=\"\(m.endings.map(String.init).joined(separator: ","))\" type=\"stop\"/>" }
                if m.repeatEnd { x += "<repeat direction=\"backward\"/>" }
                x += "</barline>\n"
            }
            x += "</measure>\n"
            previous = m
        }
        x += "</part>\n</score-partwise>\n"
        return x
    }
}
