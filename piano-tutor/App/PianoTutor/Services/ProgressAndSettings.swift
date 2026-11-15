import SwiftUI
import PianoCore

struct ProgressScreen: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Practice") {
                    LabeledContent("Time practising", value: duration(app.progress.practiceSeconds))
                    LabeledContent("Songs started", value: "\(app.songs.filter { !app.songProgress($0.id).completedSteps.isEmpty }.count) of \(app.songs.count)")
                    LabeledContent("Lessons finished", value: "\(app.progress.lessons.values.filter { $0.completed }.count) of \(app.pack.lessons.count)")
                }
                let due = app.pack.skills.filter { app.progress.skills[$0.id]?.isDue() ?? false }
                if !due.isEmpty {
                    Section("Due for review") {
                        ForEach(due) { skill in
                            if let lesson = app.pack.lessons.first(where: { $0.skillIds.contains(skill.id) }) {
                                NavigationLink { LessonView(lesson: lesson) } label: { Label(skill.title, systemImage: "arrow.clockwise") }
                            }
                        }
                    }
                }
                ForEach(Track.allCases, id: \.self) { track in
                    Section(track.title) {
                        ForEach(app.pack.skills.filter { $0.track == track }) { skill in
                            let p = app.progress.skills[skill.id]
                            HStack {
                                Text(skill.title)
                                Spacer()
                                Text(p == nil ? "Not started" : (p!.isSecure ? "Secure" : "Learning"))
                                    .foregroundStyle(p == nil ? Color.secondary : (p!.isSecure ? Color.green : Color.orange))
                            }
                        }
                    }
                }
                let history = app.progress.techniqueHistory.suffix(30)
                if history.count >= 2 {
                    Section {
                        ForEach(Array(history.reversed().prefix(10).enumerated()), id: \.offset) { _, sample in
                            HStack {
                                Text(app.song(sample.songId)?.title ?? sample.songId).lineLimit(1)
                                Spacer()
                                if let t = sample.timingSpreadMs { Text(String(format: "%.0f ms", t)).monospacedDigit() }
                                if let l = sample.legatoShare { Text(String(format: "%.0f%% joined", l * 100)).monospacedDigit().foregroundStyle(.secondary) }
                            }
                            .font(.subheadline)
                        }
                    } header: { Text("Recent clean runs: evenness") } footer: {
                        Text("Lower timing spread means more even playing. Compare like with like: the same piece at the same speed.")
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }

    private func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var confirmReset = false
    @State private var calibrating = false

    var body: some View {
        Form {
            Section("Piano") {
                NavigationLink { ConnectionView() } label: {
                    LabeledContent("Connection", value: app.isPianoConnected ? "Connected" : "Not connected")
                }
                TextField("Key Touch setting on the piano (for your notes)", text: $app.progress.settings.keyTouchNote)
                Text("Loudness figures depend on the piano's Key Touch setting. Keep it the same while you track your progress.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Practice") {
                Toggle("Strict chords (notes together)", isOn: $app.progress.settings.strictChords)
                Toggle("Metronome in time mode", isOn: $app.progress.settings.metronomeOn)
                Toggle("Play the other hand when practising one hand", isOn: $app.progress.settings.accompanyOtherHand)
                Toggle("Always show note names on the keyboard", isOn: $app.progress.settings.showNoteNames)
                Toggle("Play demonstrations on the piano", isOn: $app.progress.settings.demoThroughPiano)
            }
            Section {
                Stepper("Timing correction: \(app.progress.settings.calibrationOffsetMs) ms", value: $app.progress.settings.calibrationOffsetMs, in: -150...150, step: 5)
                Button("Measure it") { calibrating = true }
            } header: { Text("Timing") } footer: {
                Text("If the app keeps saying you are late when you feel on time, measure the delay: tap along with the clicks and the app sets the correction.")
            }
            Section("Data") {
                Button("Reset all progress", role: .destructive) { confirmReset = true }
            }
            Section("About") {
                Text("Sheet music is drawn with OpenSheetMusicDisplay (BSD 3-Clause licence). Songs are public-domain compositions arranged for this app. Lessons are drafts that have not been reviewed by a teacher.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { app.resetProgress() }
        } message: { Text("Song steps, lesson results and technique history will be cleared. Imported songs stay.") }
        .sheet(isPresented: $calibrating) { CalibrationView() }
    }
}

/// Plays 16 clicks; the learner taps any key on each. The median lateness becomes the timing correction.
struct CalibrationView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var running = false
    @State private var result: Int?
    @State private var count = 0
    @State private var clickTimes: [Int64] = []
    @State private var tapTimes: [Int64] = []
    @State private var sequencer = Sequencer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Press any key on the piano exactly with each click. Listen, don't watch the screen.").font(.title3).multilineTextAlignment(.center)
                Text(running ? "\(count) / 16" : " ").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                if let result {
                    Text("Your average delay: \(result) ms").font(.title2.weight(.semibold))
                    Button("Use this") { app.progress.settings.calibrationOffsetMs = max(-150, min(150, result)); dismiss() }.buttonStyle(.borderedProminent)
                }
                Button(running ? "Stop" : "Start") { running ? stop() : start() }.buttonStyle(.bordered).disabled(!app.isPianoConnected)
                if !app.isPianoConnected { Text("Connect the piano first.").foregroundStyle(.orange) }
            }
            .padding(30)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { stop(); dismiss() } } }
        }
        .onDisappear { stop() }
    }

    private func start() {
        result = nil; count = 0; clickTimes = []; tapTimes = []
        running = true
        let beat: Int64 = 600_000
        let start = Clock.nowUs + 800_000
        var items: [Sequencer.Item] = []
        for i in 0..<20 {
            let t = Int64(i) * beat
            items.append(.init(timeUs: t) {
                app.sound.click(accent: i % 4 == 0)
                if i >= 4 { clickTimes.append(start + t); count = i - 3 }
            })
        }
        items.append(.init(timeUs: 20 * beat) { finish() })
        app.practiceHandler = { message, timeUs in if message.type == .noteOn { tapTimes.append(timeUs) } }
        sequencer.start(items: items, startUs: start)
    }

    private func finish() {
        stop()
        var offsets: [Int64] = []
        for click in clickTimes {
            if let tap = tapTimes.min(by: { abs($0 - click) < abs($1 - click) }), abs(tap - click) < 300_000 { offsets.append(tap - click) }
        }
        guard offsets.count >= 8 else { result = nil; count = 0; return }
        let sorted = offsets.sorted()
        result = Int(sorted[sorted.count / 2] / 1000)
    }

    private func stop() {
        sequencer.stop()
        running = false
        app.practiceHandler = nil
    }
}
