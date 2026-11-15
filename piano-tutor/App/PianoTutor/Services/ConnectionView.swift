import SwiftUI
import CoreAudioKit
import PianoCore

/// Shows Apple's Bluetooth MIDI pairing screen.
struct BluetoothMIDIPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: CABTMIDICentralViewController())
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

/// Step-by-step help for connecting the Roland, plus a live test of what arrives.
struct ConnectionHelp: View {
    @EnvironmentObject private var app: AppModel
    @State private var showPairing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: app.isPianoConnected ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(app.isPianoConnected ? Color.green : Color.orange).font(.title2)
                Text(app.isPianoConnected ? "Connected" : "No piano found yet").font(.headline)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("By Bluetooth").font(.subheadline.weight(.semibold))
                Text("1. Turn the piano on. If its Bluetooth has a mode setting, choose MIDI (not page turn or audio).")
                Text("2. Close Roland's Piano Partner app or any other app that might already be connected to the piano.")
                Text("3. Tap Pair below, choose your piano in the list, and wait until it says Connected.")
                Button { showPairing = true } label: { Label("Pair Bluetooth MIDI", systemImage: "dot.radiowaves.left.and.right").frame(minHeight: 40) }
                    .buttonStyle(.borderedProminent)
                Text("By cable").font(.subheadline.weight(.semibold)).padding(.top, 6)
                Text("Connect the piano's USB \"Computer\" port to the iPad with a USB-B to USB-C cable. It is found automatically.")
            }
            .font(.subheadline)
        }
        .sheet(isPresented: $showPairing, onDismiss: { app.midi.refresh() }) { BluetoothMIDIPicker() }
    }
}

struct MIDIStatusRows: View {
    @ObservedObject var midi: MIDIManager
    var body: some View {
        LabeledContent("Last message", value: midi.lastMessageText)
        LabeledContent("Messages received", value: "\(midi.messageCount)")
        LabeledContent("Pedal", value: midi.pedalValue >= 64 ? "Down (\(midi.pedalValue))" : "Up (\(midi.pedalValue))")
    }
}

struct ConnectionView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section { ConnectionHelp() }
            Section("Test") {
                MIDIStatusRows(midi: app.midi)
                KeyboardView(lowest: 21, highest: 108, marks: Dictionary(uniqueKeysWithValues: app.heldNotes.map { ($0, KeyMark.correct) }))
                    .frame(height: 70)
                Text("Play a few keys and press the pedal. Every key you press should light up above, and the pedal should change between Up and Down.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Play a test note through the \(app.playsThroughPiano ? "piano" : "iPad")") { app.playNotes([60, 64, 67], together: false, gap: 0.3) }
            }
            Section("Sound") {
                Toggle("Play demonstrations on the piano", isOn: $app.progress.settings.demoThroughPiano)
                Text(app.midi.canSend
                     ? "When this is on, the app sends notes to the piano so you hear its own sound. Turn it off to hear them from the iPad instead."
                     : "The piano is not accepting notes from the app, so demonstrations play from the iPad.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("Look for the piano again") { app.midi.refresh() }
            }
        }
        .navigationTitle("Piano connection")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

