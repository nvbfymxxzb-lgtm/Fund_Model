import SwiftUI
import PianoCore

struct PracticeView: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var model: PracticeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLoop = false
    private let showsSteps: Bool

    init(app: AppModel, song: SongEntry, step: LearningStep? = nil, onExerciseFinished: ((AttemptReport, TechniqueReport?) -> Void)? = nil) {
        let viewModel = PracticeViewModel(app: app, song: song, step: step)
        viewModel.onExerciseFinished = onExerciseFinished
        _model = StateObject(wrappedValue: viewModel)
        showsSteps = onExerciseFinished == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                NotationView(controller: model.notation)
                NotationErrorOverlay(controller: model.notation)
                if let count = model.countInText {
                    Text(count).font(.system(size: 120, weight: .bold, design: .rounded)).foregroundStyle(.blue.opacity(0.75))
                        .accessibilityLabel("Count in \(count)")
                }
            }
            ProgressView(value: model.progressFraction).tint(.blue).accessibilityLabel("Progress through the passage")
            feedbackLine
            KeyboardView(lowest: model.keyboardRange.lowerBound, highest: model.keyboardRange.upperBound, marks: model.keyMarks, labels: model.keyLabels)
                .frame(height: 128)
                .padding(.horizontal, 6)
            controls
        }
        .navigationTitle(model.song.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ConnectionBadge() }
        }
        .onAppear { model.appear() }
        .onDisappear { model.disappear() }
        .sheet(isPresented: $model.showSummary) { SummaryView(model: model, showsSteps: showsSteps, close: { dismiss() }) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let step = model.step {
                Label(step.title, systemImage: "figure.walk").font(.subheadline.weight(.semibold))
            } else {
                Label("Free practice", systemImage: "pianokeys").font(.subheadline.weight(.semibold))
            }
            Spacer()
            Text(passageText).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private var passageText: String {
        let a = model.score.measures.indices.contains(model.firstMeasure) ? model.score.measures[model.firstMeasure].number : "1"
        let b = model.score.measures.indices.contains(model.lastMeasure) ? model.score.measures[model.lastMeasure].number : a
        return a == b ? "Measure \(a)" : "Measures \(a)–\(b)"
    }

    private var feedbackLine: some View {
        Text(model.feedback.isEmpty ? " " : model.feedback)
            .font(.title3.weight(.medium))
            .lineLimit(2).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button { model.isBusy ? model.stop() : model.playDemo() } label: {
                Label(model.phase == .demo ? "Stop" : "Listen", systemImage: model.phase == .demo ? "stop.fill" : "ear")
                    .frame(minWidth: 96, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(model.phase == .playing || model.phase == .countIn)

            Button { (model.phase == .playing || model.phase == .countIn) ? model.stop() : model.start() } label: {
                Label((model.phase == .playing || model.phase == .countIn) ? "Stop" : "Start",
                      systemImage: (model.phase == .playing || model.phase == .countIn) ? "stop.fill" : "play.fill")
                    .font(.title3.weight(.bold)).frame(minWidth: 130, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.phase == .demo)

            Divider().frame(height: 36)

            Picker("Hand", selection: $model.hand) {
                Text("Left").tag(HandSelection.left)
                Text("Both").tag(HandSelection.both)
                Text("Right").tag(HandSelection.right)
            }
            .pickerStyle(.segmented).frame(width: 210)
            .onChange(of: model.hand) { _, _ in model.passageChanged() }

            Picker("Mode", selection: $model.mode) {
                Text("Wait for me").tag(PracticeMode.wait)
                Text("In time").tag(PracticeMode.rhythm)
            }
            .pickerStyle(.segmented).frame(width: 220)
            .onChange(of: model.mode) { _, _ in model.passageChanged() }

            Stepper(value: $model.tempoPercent, in: 40...120, step: 5) {
                Text("Speed \(model.tempoPercent)%").monospacedDigit()
            }
            .frame(width: 220)
            .disabled(model.mode == .wait && model.phase != .demo)

            Spacer(minLength: 0)

            Button { showLoop = true } label: {
                Label("Loop", systemImage: "repeat").frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)
            .popover(isPresented: $showLoop) { loopEditor }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private var loopEditor: some View {
        let last = max(model.score.measures.count - 1, 0)
        return VStack(alignment: .leading, spacing: 16) {
            Text("Practise part of the piece").font(.headline)
            Stepper("From measure \(model.score.measures.indices.contains(model.firstMeasure) ? model.score.measures[model.firstMeasure].number : "1")",
                    value: $model.firstMeasure, in: 0...last)
            Stepper("To measure \(model.score.measures.indices.contains(model.lastMeasure) ? model.score.measures[model.lastMeasure].number : "1")",
                    value: $model.lastMeasure, in: 0...last)
            Button("Whole piece") { model.selectWholePiece() }
            Text("You can also tap a measure in the music to start there, then tap a later measure to end the loop.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 340)
        .onChange(of: model.firstMeasure) { _, _ in model.step = nil; model.passageChanged() }
        .onChange(of: model.lastMeasure) { _, _ in model.step = nil; model.passageChanged() }
    }
}

struct NotationErrorOverlay: View {
    @ObservedObject var controller: NotationController
    var body: some View {
        if let error = controller.errorMessage {
            Text(error).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12)).padding()
        }
    }
}

/// A small dot in the toolbar that shows whether the piano is connected.
struct ConnectionBadge: View {
    @EnvironmentObject private var app: AppModel
    @State private var showConnection = false

    var body: some View {
        Button { showConnection = true } label: {
            Label(app.isPianoConnected ? "Piano connected" : "No piano", systemImage: app.isPianoConnected ? "pianokeys.inverse" : "exclamationmark.triangle")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(app.isPianoConnected ? Color.green : Color.orange)
        }
        .sheet(isPresented: $showConnection) { NavigationStack { ConnectionView() } }
    }
}

struct SummaryView: View {
    @ObservedObject var model: PracticeViewModel
    let showsSteps: Bool
    let close: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let report = model.report {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: icon(report.result)).font(.system(size: 40)).foregroundStyle(color(report.result))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title(report.result)).font(.title2.weight(.bold))
                                Text(model.suggestion?.message ?? "").foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    Section("Notes") {
                        row("Played correctly", "\(report.matchedCount) of \(report.scoredCount)")
                        if report.mode == .rhythm { row("On the beat", "\(report.onTimeCount) of \(report.matchedCount)") }
                        if report.missedCount > 0 { row("Missed", "\(report.missedCount)") }
                        if report.wrongCount > 0 { row("Wrong notes", "\(report.wrongCount)") }
                        if report.extraCount > 0 { row("Extra notes", "\(report.extraCount)") }
                        if report.excludedCount > 0 { row("Not graded", "\(report.excludedCount)") }
                        if report.assisted { row("Hints", "Used") }
                        if !report.troubleMeasures.isEmpty {
                            row("Measures to work on", report.troubleMeasures.prefix(3).map { model.score.measures.indices.contains($0) ? model.score.measures[$0].number : "\($0 + 1)" }.joined(separator: ", "))
                        }
                    }
                    if let t = model.technique, report.result != .inconclusive, t.timingSpreadMs != nil {
                        Section {
                            if let v = t.timingSpreadMs { row("Evenness of timing", String(format: "%.0f ms spread", v), hint: "Lower is more even.") }
                            if let v = t.velocitySpread { row("Evenness of loudness", String(format: "%.0f", v), hint: "Lower is more even. Use it only when you meant to play at one level.") }
                            if let share = t.legatoShare, let overlap = t.legatoOverlapMs {
                                row("Joined notes (legato)", String(format: "%.0f%% joined, %+.0f ms", share * 100, overlap), hint: "A small positive overlap is legato. Negative means gaps.")
                            }
                            if let v = t.handBalance { row("Balance, right minus left", String(format: "%+.0f", v), hint: "Positive means the right hand was louder.") }
                            if let v = t.handSyncMs { row("Hands together", String(format: "%.0f ms apart", v), hint: "How far apart the hands landed when they should be together.") }
                            ForEach(t.outliers.prefix(3), id: \.self) { o in
                                Text("Measure \(model.score.measures.indices.contains(o.measureIndex) ? model.score.measures[o.measureIndex].number : "?"): a note was \(o.reason) than the rest.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        } header: { Text("How it sounded") } footer: {
                            Text("These figures come from the keys you pressed. They describe the sound, not your hand position, and they depend on your piano's Key Touch setting.")
                        }
                    }
                }
            }
            .navigationTitle("Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back to the music") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.suggestionButtonTitle) {
                        if model.suggestion?.action == .nextStep && (model.nextStep == nil || !showsSteps) { dismiss(); close() }
                        else { model.applySuggestion() }
                    }
                    .font(.headline)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ label: String, _ value: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary).monospacedDigit() }
            if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
        }
    }
    private func title(_ r: AttemptResult) -> String {
        switch r { case .pass: return "Clean run"; case .fail: return "Not yet"; case .inconclusive: return "Could not grade this run" }
    }
    private func icon(_ r: AttemptResult) -> String {
        switch r { case .pass: return "checkmark.circle.fill"; case .fail: return "arrow.counterclockwise.circle.fill"; case .inconclusive: return "questionmark.circle.fill" }
    }
    private func color(_ r: AttemptResult) -> Color {
        switch r { case .pass: return .green; case .fail: return .orange; case .inconclusive: return .gray }
    }
}
