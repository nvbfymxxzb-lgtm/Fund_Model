import Foundation
import AVFoundation

/// Plays notes and metronome clicks through the iPad when the piano is not used for sound.
/// It uses the system's built-in sampler tone, so no sound files are bundled.
final class SoundPlayer {
    private let engine = AVAudioEngine()
    private let piano = AVAudioUnitSampler()
    private let clicker = AVAudioUnitSampler()
    private var running = false

    init() {
        engine.attach(piano)
        engine.attach(clicker)
        engine.connect(piano, to: engine.mainMixerNode, format: nil)
        engine.connect(clicker, to: engine.mainMixerNode, format: nil)
    }

    func start() {
        guard !running else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            running = true
        } catch {
            running = false
        }
    }

    func noteOn(_ note: Int, velocity: Int) {
        start()
        guard running else { return }
        piano.startNote(UInt8(clamping: note), withVelocity: UInt8(clamping: max(1, min(127, velocity))), onChannel: 0)
    }

    func noteOff(_ note: Int) {
        guard running else { return }
        piano.stopNote(UInt8(clamping: note), onChannel: 0)
    }

    func click(accent: Bool) {
        start()
        guard running else { return }
        let note: UInt8 = accent ? 103 : 96
        clicker.startNote(note, withVelocity: accent ? 120 : 90, onChannel: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in self?.clicker.stopNote(note, onChannel: 0) }
    }

    func silence() {
        guard running else { return }
        for note in 21...108 { piano.stopNote(UInt8(note), onChannel: 0) }
    }
}

/// Fires a list of timed actions against the host clock.
final class Sequencer {
    struct Item {
        let timeUs: Int64
        let action: () -> Void
    }

    private var timer: DispatchSourceTimer?
    private var items: [Item] = []
    private var next = 0
    private(set) var startUs: Int64 = 0
    var isRunning: Bool { timer != nil }

    /// `startUs` is the host time (in microseconds) that counts as time zero. Items may have negative times (a count-in).
    func start(items: [Item], startUs: Int64) {
        stop()
        self.items = items.enumerated().sorted { ($0.element.timeUs, $0.offset) < ($1.element.timeUs, $1.offset) }.map { $0.element }
        self.next = 0
        self.startUs = startUs
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(3), leeway: .milliseconds(1))
        source.setEventHandler { [weak self] in self?.tick() }
        timer = source
        source.resume()
    }

    private func tick() {
        let now = Clock.nowUs - startUs
        while next < items.count, items[next].timeUs <= now {
            let item = items[next]
            next += 1
            item.action()
        }
        if next >= items.count { stop() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
