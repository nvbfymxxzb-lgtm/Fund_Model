import SwiftUI
import PianoCore

@main
struct PianoTutorApp: App {
    @StateObject private var app = AppModel()
    @AppStorage("didOnboard") private var didOnboard = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .sheet(isPresented: Binding(get: { !didOnboard }, set: { if !$0 { didOnboard = true } })) {
                    WelcomeView { didOnboard = true }.environmentObject(app)
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            SongsView().tabItem { Label("Songs", systemImage: "music.note.list") }
            TheoryView().tabItem { Label("Theory", systemImage: "book") }
            ProgressScreen().tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var app: AppModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Learn real pieces step by step on your own piano, with the theory and technique behind them.")
                        .font(.title2)
                    Label("Songs are ordered from easiest to hardest. Each one is broken into small steps: one hand, then both, slowly, then up to speed.", systemImage: "music.note.list")
                    Label("Theory has two parts: piano technique and theory, and general music theory. Most questions are answered on your piano.", systemImage: "book")
                    Label("The app hears which keys you press and when. It cannot see your hands, so it never comments on your posture or fingering.", systemImage: "ear")
                    Divider()
                    Text("Connect your piano").font(.headline)
                    ConnectionHelp()
                    Button { done() } label: {
                        Text(app.isPianoConnected ? "Start" : "Continue without the piano for now").font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(28)
            }
            .navigationTitle("Welcome")
        }
        .interactiveDismissDisabled()
    }
}
