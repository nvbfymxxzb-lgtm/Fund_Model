# Piano Tutor

An iPad app that teaches piano step by step on your own Roland FRP-1, over Bluetooth MIDI or a USB cable.

- **Songs**: 11 starter pieces ranked from easiest to hardest (levels 1–5). Each piece is broken into steps: listen, each phrase hand by hand, hands together, slowly in time, joined phrases, the hardest bars, then the whole piece. You can also import your own MusicXML (`.musicxml`, `.mxl`) files.
- **Theory**, in two tracks:
  - *Piano technique & theory*: 4 units, 13 lessons (setup, scales and fingering, chords and inversions, touch, balance, pedal, practising).
  - *Music theory*: 4 units, 10 lessons (rhythm and meter, intervals, keys, chords and progressions).
  - Most questions are answered on the piano. Generated question sets give unlimited practice.
- **Grading** you can trust: *Wait for me* mode stops until you play the right notes. *In time* mode grades every note against the beat. A dropped connection never counts as mistakes, and the same performance always gets the same grade.
- **How it sounded**: after a clean run the app reports evenness of timing and loudness, legato joins, balance between the hands, and how together the hands land. It says plainly that it hears the result, not your hands.

## Getting it onto your iPad

You need your Mac with Xcode, your iPad Pro and the piano.

1. In Terminal, go to this folder and run `./setup.sh`.
   - It installs XcodeGen through Homebrew if needed, creates `PianoTutor.xcodeproj`, runs the core tests and opens Xcode.
   - If you don't have Homebrew, install it from https://brew.sh first.
2. In Xcode, select the **PianoTutor** target, open **Signing & Capabilities**, and choose your Apple ID as the **Team**.
   - Change the bundle identifier from `com.yourname.pianotutor` to anything unique.
   - A free Apple ID works, but the app then has to be reinstalled every 7 days. The paid developer program removes that limit.
3. Plug in the iPad, choose it as the run destination, and press **Run** (⌘R).
   - The first time, the iPad asks you to trust the developer: open **Settings → General → VPN & Device Management**.
4. In the app, follow the welcome screen to connect the piano:
   - **Bluetooth:** close Roland's Piano Partner app, then use **Pair Bluetooth MIDI** inside this app. Bluetooth MIDI does not pair from iPad Settings.
   - **Cable:** a USB-B to USB-C cable from the piano's USB Computer port works straight away.
   - **Check:** use **Settings → Piano → Connection** to confirm every key lights up and the pedal shows Up and Down.

## What has and has not been checked

| Part | Status |
|---|---|
| Music model, MusicXML/MXL import, grading, technique figures, difficulty ranking, theory engine, all bundled songs and lessons | **58 automated tests pass** (Linux, Swift 6.0). Every bundled song is checked to pass when played perfectly and to read back from its notation file unchanged. Every lesson question is checked to have a valid answer, and every scale and chord spelling is checked against a hand-made table. |
| Sheet-music drawing and note highlighting | Tested in a real browser: every note the app grades is found in the drawn score for all 11 songs. |
| iPad app screens (SwiftUI, Core MIDI, audio, web view) | Written but **not yet compiled**: there is no Xcode in the environment where this was built. The core's public API is checked by a test that uses it exactly as the app does, and every app file passes a syntax check. Expect possibly a few small compile fixes the first time you build. |
| Your Roland FRP-1 and iPad | **Not tested.** Bluetooth MIDI support comes from retailer listings. Things to try first: pairing, demonstrations through the piano's speakers, the pedal, and the timing correction (Settings → Timing → Measure it). |
| Lesson content and song arrangements | Drafts. **No piano teacher has reviewed them.** Facts and answers are machine-checked; technique advice is kept to widely agreed basics. Some songs were written out from memory, which each song's page says. Compare them with a printed edition. |

## Project layout

```
piano-tutor/
  setup.sh, project.yml         make the Xcode project (XcodeGen)
  App/PianoTutor/               the iPad app (SwiftUI)
    Services/                   MIDI, sound, shared state, connection, progress, settings
    Practice/                   practice screen, notation view, keyboard drawing
    Songs/  Theory/             the two sections
    Resources/notation/         sheet-music page (OpenSheetMusicDisplay 1.9.0, BSD-3-Clause)
  PianoCore/                    Swift package with all the logic, testable without an iPad
    Sources/MusicModel          notes, timing, repeats, song text format, MusicXML writer
    Sources/ScoreImport         MusicXML and compressed MXL import, with safety limits
    Sources/PracticeEngine      wait/rhythm grading, technique figures, lesson steps, coach
    Sources/Difficulty          difficulty score, levels and "what makes it hard"
    Sources/TheoryKit           scales, chords, keys, intervals, exercise generators and checkers
    Sources/Curriculum          skills, lessons, songs, saved progress; Content/ holds the JSON
    Sources/pianotool           command-line helper: rank, check a file, grade a recording
    Tests/                      58 tests
  tools/build_songs.py          edit songs here, then run it to regenerate the song files
  tools/build_lessons.py        edit lessons here, then run it to regenerate the lesson files
  tools/notation-test/          browser test for the sheet-music page
  docs/PLAN.md                  the refined plan (v3); docs/ORIGINAL-PLAN.md is the first plan
```

Run the core tests on the Mac with `cd PianoCore && swift test`. Check a MusicXML file before importing it with `swift run pianotool check song.mxl`.

## Changing content

Songs and lessons are generated from the two Python scripts in `tools/`. Edit those scripts, run them, and run `swift test`. The tests reject a song whose measures don't add up, a lesson question without a valid answer, or a misspelled chord.

## Known limits and next steps

1. **First build on the Mac:** fix any compile errors in the app screens. The logic underneath is tested.
2. **Hardware check with the FRP-1:**
   - pairing, and the latency figures in the plan (docs/PLAN.md §10);
   - whether the piano plays notes the app sends;
   - pedal values;
   - the timing correction.
3. **Demonstration sound without the piano:** the iPad fallback uses the system's plain sampler tone. Bundling a properly licensed piano sample set would sound better.
4. **Not built yet:** PDF/photo sheet-music recognition, microphone listening, MIDI-file import, and the free-tempo follower. See the plan's later phases.
5. **Content:**
   - More songs at levels 5–6.
   - The difficulty levels are fitted to only 11 pieces. Rank correlation with the assigned levels is 0.89, which is a rough calibration.
   - A one-off lesson with a teacher to check your hand position is still recommended.
