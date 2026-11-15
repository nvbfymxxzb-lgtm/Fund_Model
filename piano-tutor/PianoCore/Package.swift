// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PianoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PianoCore", targets: ["PianoCore"]),
    ],
    targets: [
        .target(name: "MusicModel"),
        .target(name: "ScoreImport", dependencies: ["MusicModel"]),
        .target(name: "PracticeEngine", dependencies: ["MusicModel"]),
        .target(name: "Difficulty", dependencies: ["MusicModel"]),
        .target(name: "TheoryKit", dependencies: ["MusicModel", "PracticeEngine"]),
        .target(name: "Curriculum", dependencies: ["MusicModel", "ScoreImport", "PracticeEngine", "Difficulty", "TheoryKit"],
                resources: [.copy("Content")]),
        .target(name: "PianoCore", dependencies: ["MusicModel", "ScoreImport", "PracticeEngine", "Difficulty", "TheoryKit", "Curriculum"]),
        .executableTarget(name: "pianotool", dependencies: ["MusicModel", "ScoreImport", "PracticeEngine", "Difficulty", "Curriculum"]),
        .testTarget(name: "PianoCoreTests",
                    dependencies: ["MusicModel", "ScoreImport", "PracticeEngine", "Difficulty", "TheoryKit", "Curriculum"],
                    resources: [.copy("Fixtures")]),
    ],
    swiftLanguageVersions: [.v5]
)
