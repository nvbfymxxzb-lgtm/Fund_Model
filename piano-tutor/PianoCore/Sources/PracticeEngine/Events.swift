import Foundation
import MusicModel

public enum InputSource: String, Codable, Sendable { case bleMidi, usbMidi, virtual, replay, screen }
public enum EventType: String, Codable, Sendable { case noteOn, noteOff, pedal, allNotesOff, disconnect, reconnect }

/// One thing the learner did, with its time in microseconds from the start of the passage.
public struct PerformanceEvent: Codable, Hashable, Sendable {
    public var seq: Int64
    public var type: EventType
    public var pitch: Int?
    public var velocity: Int?
    public var channel: Int?
    public var pedalValue: Int?
    public var timeUs: Int64
    public var source: InputSource

    public init(seq: Int64, type: EventType, pitch: Int? = nil, velocity: Int? = nil, channel: Int? = nil,
                pedalValue: Int? = nil, timeUs: Int64, source: InputSource = .replay) {
        self.seq = seq; self.type = type; self.pitch = pitch; self.velocity = velocity; self.channel = channel
        self.pedalValue = pedalValue; self.timeUs = timeUs; self.source = source
    }

    public static func noteOn(_ pitch: Int, at timeUs: Int64, velocity: Int = 80, seq: Int64 = 0) -> PerformanceEvent {
        PerformanceEvent(seq: seq, type: .noteOn, pitch: pitch, velocity: velocity, timeUs: timeUs)
    }
    public static func noteOff(_ pitch: Int, at timeUs: Int64, seq: Int64 = 0) -> PerformanceEvent {
        PerformanceEvent(seq: seq, type: .noteOff, pitch: pitch, velocity: 0, timeUs: timeUs)
    }
}

/// Turns raw MIDI 1.0 messages into the app's events.
public enum MIDIDecoder {
    public struct Message: Equatable, Sendable {
        public var type: EventType
        public var pitch: Int?
        public var velocity: Int?
        public var channel: Int
        public var pedalValue: Int?
    }

    /// Decodes one channel message. Returns nil for messages the app ignores.
    public static func decode(status: UInt8, data1: UInt8, data2: UInt8) -> Message? {
        let kind = status & 0xF0
        let channel = Int(status & 0x0F) + 1
        switch kind {
        case 0x90:
            // A note-on with velocity 0 means note-off.
            if data2 == 0 { return Message(type: .noteOff, pitch: Int(data1), velocity: 0, channel: channel) }
            return Message(type: .noteOn, pitch: Int(data1), velocity: Int(data2), channel: channel)
        case 0x80:
            return Message(type: .noteOff, pitch: Int(data1), velocity: Int(data2), channel: channel)
        case 0xB0:
            if data1 == 64 { return Message(type: .pedal, channel: channel, pedalValue: Int(data2)) }
            if data1 == 120 || data1 == 123 { return Message(type: .allNotesOff, channel: channel) }
            return nil
        default:
            return nil
        }
    }

    /// Decodes a Universal MIDI Packet word that carries a MIDI 1.0 channel message (message type 2).
    public static func decode(umpWord word: UInt32) -> Message? {
        guard (word >> 28) & 0xF == 0x2 else { return nil }
        return decode(status: UInt8((word >> 16) & 0xFF), data1: UInt8((word >> 8) & 0x7F), data2: UInt8(word & 0x7F))
    }
}

/// Keeps track of which keys and pedal are down.
public struct ActiveNotes: Sendable {
    public private(set) var held: Set<Int> = []
    public private(set) var pedalDown = false
    public init() {}

    public mutating func apply(_ e: PerformanceEvent) {
        switch e.type {
        case .noteOn: if let p = e.pitch { held.insert(p) }
        case .noteOff: if let p = e.pitch { held.remove(p) }
        case .pedal: pedalDown = (e.pedalValue ?? 0) >= 64
        case .allNotesOff, .disconnect: held.removeAll(); pedalDown = false
        case .reconnect: break
        }
    }
}

public enum PracticeMode: String, Codable, Sendable, CaseIterable { case wait, rhythm }

public struct TraceHeader: Codable, Hashable, Sendable {
    public var traceVersion = 1
    public var evaluatorVersion = Evaluator.version
    public var toleranceVersion = Tolerances.version
    public var songId: String
    public var passage: Passage
    public var hand: HandSelection
    public var mode: PracticeMode
    public var tempoPercent: Int
    public var calibrationOffsetUs: Int64
    public var inputName: String

    public init(songId: String, passage: Passage, hand: HandSelection, mode: PracticeMode, tempoPercent: Int,
                calibrationOffsetUs: Int64 = 0, inputName: String = "") {
        self.songId = songId; self.passage = passage; self.hand = hand; self.mode = mode
        self.tempoPercent = tempoPercent; self.calibrationOffsetUs = calibrationOffsetUs; self.inputName = inputName
    }
}

/// A recorded performance that can be replayed through the grader to get the same result again.
public struct PerformanceTrace: Hashable, Sendable {
    public var header: TraceHeader
    public var events: [PerformanceEvent]

    public init(header: TraceHeader, events: [PerformanceEvent]) { self.header = header; self.events = events }

    static var encoder: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }

    /// One JSON object per line: the header first, then each event.
    public func jsonLines() throws -> String {
        var lines = [String(decoding: try PerformanceTrace.encoder.encode(header), as: UTF8.self)]
        for e in events { lines.append(String(decoding: try PerformanceTrace.encoder.encode(e), as: UTF8.self)) }
        return lines.joined(separator: "\n") + "\n"
    }

    public init(jsonLines text: String) throws {
        let lines = text.split(separator: "\n").map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let first = lines.first else { throw CocoaError(.fileReadCorruptFile) }
        let d = JSONDecoder()
        header = try d.decode(TraceHeader.self, from: Data(first.utf8))
        events = try lines.dropFirst().map { try d.decode(PerformanceEvent.self, from: Data($0.utf8)) }
    }
}
