import Foundation
import CoreMIDI
import PianoCore

/// Talks to the piano through Core MIDI: listens to every MIDI source (USB or Bluetooth) and can send notes back.
final class MIDIManager: ObservableObject {
    @Published private(set) var sourceNames: [String] = []
    @Published private(set) var destinationNames: [String] = []
    @Published private(set) var lastMessageText = "Nothing received yet"
    @Published private(set) var pedalValue = 0
    @Published private(set) var messageCount = 0

    var isConnected: Bool { !sourceNames.isEmpty }
    var canSend: Bool { !destinationNames.isEmpty }

    /// Called on the main thread for every note and pedal message, with the time it happened in microseconds.
    var onMessage: ((MIDIDecoder.Message, Int64) -> Void)?
    /// Called on the main thread when the last input disappears or the first one appears.
    var onConnectionChange: ((Bool) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var connectedSources: [MIDIEndpointRef] = []
    private var refreshPending = false

    init() {
        let status = MIDIClientCreateWithBlock("PianoTutor" as CFString, &client) { [weak self] _ in
            // Any change to the MIDI setup: look again, once, shortly afterwards.
            DispatchQueue.main.async { self?.scheduleRefresh() }
        }
        guard status == noErr else { lastMessageText = "MIDI is not available on this device (error \(status))."; return }
        MIDIInputPortCreateWithProtocol(client, "PianoTutor In" as CFString, ._1_0, &inputPort) { [weak self] eventList, _ in
            self?.receive(eventList)
        }
        MIDIOutputPortCreate(client, "PianoTutor Out" as CFString, &outputPort)
        refresh()
    }

    private func scheduleRefresh() {
        guard !refreshPending else { return }
        refreshPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshPending = false
            self?.refresh()
        }
    }

    private func name(of endpoint: MIDIEndpointRef) -> String {
        var value: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value) == noErr, let value {
            return value.takeRetainedValue() as String
        }
        return "MIDI device"
    }

    private func isOffline(_ endpoint: MIDIEndpointRef) -> Bool {
        var offline: Int32 = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &offline)
        return offline != 0
    }

    /// Finds the current MIDI sources and destinations and listens to every source.
    func refresh() {
        let wasConnected = isConnected
        var sources: [MIDIEndpointRef] = []
        for i in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(i)
            if endpoint != 0 && !isOffline(endpoint) { sources.append(endpoint) }
        }
        for old in connectedSources where !sources.contains(old) { MIDIPortDisconnectSource(inputPort, old) }
        for new in sources where !connectedSources.contains(new) { MIDIPortConnectSource(inputPort, new, nil) }
        connectedSources = sources
        sourceNames = sources.map { name(of: $0) }

        var destinations: [String] = []
        for i in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(i)
            if endpoint != 0 && !isOffline(endpoint) { destinations.append(name(of: endpoint)) }
        }
        destinationNames = destinations
        if wasConnected != isConnected { onConnectionChange?(isConnected) }
    }

    private func receive(_ eventList: UnsafePointer<MIDIEventList>) {
        var decoded: [(MIDIDecoder.Message, Int64)] = []
        for packet in eventList.unsafeSequence() {
            let stamp = packet.pointee.timeStamp
            let timeUs = stamp == 0 ? Clock.nowUs : Clock.microseconds(hostTime: stamp)
            let count = Int(packet.pointee.wordCount)
            withUnsafeBytes(of: packet.pointee.words) { raw in
                let words = raw.bindMemory(to: UInt32.self)
                for i in 0..<min(count, words.count) {
                    if let message = MIDIDecoder.decode(umpWord: words[i]) { decoded.append((message, timeUs)) }
                }
            }
        }
        guard !decoded.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for (message, timeUs) in decoded {
                self.messageCount += 1
                switch message.type {
                case .noteOn: self.lastMessageText = "Key down: \(MIDINote.name(message.pitch ?? 0)), strength \(message.velocity ?? 0)"
                case .noteOff: self.lastMessageText = "Key up: \(MIDINote.name(message.pitch ?? 0))"
                case .pedal: self.pedalValue = message.pedalValue ?? 0; self.lastMessageText = "Pedal: \(message.pedalValue ?? 0)"
                default: break
                }
                self.onMessage?(message, timeUs)
            }
        }
    }

    private func send(status: UInt8, data1: UInt8, data2: UInt8) {
        guard canSend else { return }
        var word = UInt32(0x2000_0000) | (UInt32(status) << 16) | (UInt32(data1) << 8) | UInt32(data2)
        let size = MemoryLayout<MIDIEventList>.size
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<MIDIEventList>.alignment)
        defer { buffer.deallocate() }
        let list = buffer.bindMemory(to: MIDIEventList.self, capacity: 1)
        let packet = MIDIEventListInit(list, ._1_0)
        _ = MIDIEventListAdd(list, size, packet, 0, 1, &word)
        for i in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(i)
            if endpoint != 0 && !isOffline(endpoint) { MIDISendEventList(outputPort, endpoint, list) }
        }
    }

    func noteOn(_ note: Int, velocity: Int) { send(status: 0x90, data1: UInt8(clamping: note), data2: UInt8(clamping: max(1, min(127, velocity)))) }
    func noteOff(_ note: Int) { send(status: 0x80, data1: UInt8(clamping: note), data2: 0) }
    /// Silences anything the app started on the piano.
    func allNotesOff() { send(status: 0xB0, data1: 123, data2: 0) }
}
