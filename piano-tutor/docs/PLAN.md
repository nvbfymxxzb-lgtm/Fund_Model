# Piano tutor: refinement v3
## Native iPad Pro app · Roland FRP-1 over Bluetooth MIDI · Songs + Theory for advanced beginners · built without a piano teacher
Refines: *Piano tutor app: Product and engineering build plan* (Nov 13, 2026)
Status: planning document. No code has been built or run, and no hardware has been tested.

**Who it is for:** advanced beginners who can already play chords with both hands. They want step-by-step help learning pieces, better technique, and a real understanding of theory.

**How the app is organized:**
1. **Songs**: a library ranked by difficulty, where each piece is broken into guided steps.
2. **Theory**, in two parts:
   - **Piano theory & technique**: keyboard-specific skills such as scales and fingering, chord voicings, pedaling, touch and voicing.
   - **Music theory**: general musicianship such as intervals, keys, harmony, rhythm, form and ear training.

**How to read this document:**
- **Part 1** (§0–§15) is the platform and practice engine from v1, updated for your answers.
- **Part 2** (§16–§21) covers the two sections, the difficulty ranking, the curriculum, what technique feedback MIDI can and cannot give, and how the content is made.
- **§22 (new in v3)** replaces every "teacher review" step in this document with a no-teacher process. **Wherever the text says "teacher", apply §22.**

---

## 0. What this refinement changes

| Topic | Original plan | This refinement |
|---|---|---|
| Platform | Three options, undecided | **Native Swift/SwiftUI app for iPadOS/iOS**, using Core MIDI and AVAudioEngine |
| Input | MIDI preferred, transport unknown | **Bluetooth LE MIDI** as the main input. USB MIDI (through an adapter) is the reference and diagnostic path if the keyboard has a USB port |
| Notation | OSMD or Verovio | **OSMD in a bundled, offline WKWebView** for notation. **Native SwiftUI keyboard strip** for the immediate, latency-critical feedback |
| Timebase | "One monotonic timebase" | **Mach host time.** Core MIDI timestamps and AVAudioTime both use it, so input and playback share one clock without conversion |
| Units | Rational beats | **Rational fractions of a whole note** (a quarter note is 1/4). This avoids "beat" ambiguity in compound meters |
| Evaluator | Rules described in prose | A **deterministic spec** (§8): integer microseconds, order-preserving matching per pitch, fixed tie-breaks |
| Scope | P0 backlog | P0 is narrowed to the exact MusicXML subset in §4. The free-tempo follower moves to P1 |
| Product structure | Song-first, theory not specified | **Two sections: Songs (ranked by difficulty) and Theory (piano technique & theory + general music theory)**, connected by a shared skill map (§16–§21) |
| Audience | Unspecified beginner | **Advanced beginners** (can play two-handed chords) moving toward early intermediate |
| Technique | "Do not infer technique" | Kept, and made precise: MIDI **can** measure evenness, legato overlap, touch and dynamics, voicing balance and pedal timing. It **cannot** see posture, hand shape or which finger was used (§19) |
| Demonstration sound | Licensed sample set | **Your Roland piano's own sound over MIDI** is the first choice, with a bundled sampler as the fallback (§10) |

What is still unknown, and what each answer would change, is listed in §1.

---

## 1. Decisions: locked and still open

### Locked by your answers
- **Build machine:** you have a Mac, so the native path is confirmed.
- **Practice device:** an **iPad Pro 11-inch (M4)**, used in landscape. It has a USB-C port and plenty of performance headroom, so app performance is not a concern. The minimum iPadOS version is whatever the iPad runs when development starts. iPhone is not a target.
- **Instrument:** a **Roland FRP-1** (the Costco digital piano bundle, around 2020).
- **Input:** Bluetooth MIDI first. A USB cable is the reference and diagnostic path.
- **Content review:** **there is no piano teacher.** §22 sets out the substitute process.
- **Audience and structure:** advanced beginners, with Songs ranked by difficulty and Theory in two parts.
- **This session's output:** plan documents only, kept as local files with no commits.

### Roland FRP-1: what was found and what to check
Roland's own FRP-1 specification page was not found in a quick web search on Nov 13, 2026. These points come from retailer and third-party listings, so **confirm each in the FRP-1 owner's manual** (step S0-1):

| Feature | What was found | Confidence | What it means for the app |
|---|---|---|---|
| Bluetooth MIDI | Listings describe Bluetooth MIDI to Roland's *Piano Partner 2* app | Good | The main input works as planned. **Close Piano Partner 2** before using this app, because only one app can hold the connection |
| USB to computer | A piano-database listing shows "USB to Computer" | Moderate | Use a **USB-B to USB-C cable** straight into the iPad Pro, with no adapter. This is the reference path |
| Bluetooth audio (streaming music to the piano's speakers) | Not mentioned in FRP-1 listings | Probably absent | **No impact.** This app uses MIDI, not audio streaming |
| MIDI input (piano plays notes the app sends) | Not stated, but Piano Partner 2 changes the piano's sounds and settings over MIDI, which suggests it does | Moderate | Demonstrations would play through the piano's own speakers (§10). If not, the iPad sampler is the fallback |
| Pedal | Depends on what the bundle included (a simple switch or a continuous pedal) | Unknown | A switch sends only on/off. A continuous pedal sends a range of values. Both work: the engine records the raw value and treats ≥ 64 as "pedal down" (§8.2). Half-pedal feedback only applies with a continuous pedal |
| Note-off sent as a note-on with velocity 0 | Common practice | – | Already handled (§8.2) |

Other points:
- **Pairing:** BLE MIDI instruments usually do not pair in iPad Settings. They connect through an app's Bluetooth MIDI dialog, which this app provides (§7).
- **Key Touch:** the FRP-1's key-touch (velocity sensitivity) setting changes the velocities it sends. The app records the setting in calibration (§19.1). **Keep it fixed** while tracking your technique progress.

### Still open (none of these block planning)
1. **Who writes the code** (you with AI help, or an engineer). This changes the estimate in §12 but not the architecture.
2. **Personal use only, or the App Store later.** This changes the review of sample and repertoire licensing, privacy labels and signing (free provisioning versus the paid developer program). It does not change the MVP architecture.
3. **Whether to book a few one-off lessons** as technique check-ins (§22.4). This is optional, but it is the only way to cover what MIDI cannot see.

---

## 2. Platform decision

**Selected: a native SwiftUI iPad app (landscape first) with Swift packages for the core logic.**

Why:
- On iOS, Core MIDI is the documented route to BLE MIDI. It includes Apple's Bluetooth MIDI pairing UI in CoreAudioKit, and after connecting, a BLE device shows up as an ordinary MIDI endpoint.
- Core MIDI timestamps and AVAudioEngine render times are both in host time. Input events and demonstration playback can share one clock without cross-clock estimation.
- The core packages (music model, import, evaluator) can be **pure Swift with no Apple UI dependencies**. They can be compiled and unit-tested on Linux or in CI, and in this cloud environment, while the app shell is built on a Mac.
- The same code can run on an Apple-silicon Mac ("Designed for iPad"). That gives a convenient development loop with a USB keyboard. Acceptance still happens on your iPad with your Roland.

**Rejected alternatives:**

| Alternative | Reason rejected for this MVP |
|---|---|
| Web app in Safari on iPad/iPhone | Safari has no native Web MIDI. Other iOS browsers do not change that. |
| React Native / Flutter | BLE MIDI and low-latency audio would still need native bridges, which adds a layer and a dependency on plugin maintenance for a single platform. Revisit only if Android becomes a requirement. |
| Fully native notation renderer | No established open-source Swift MusicXML engraver was identified. Writing one is out of scope. |
| Verovio as the first renderer | It is a capable fallback, but LGPLv3 obligations inside an iOS app need legal review (relinking and distribution). It stays the evaluated alternative to OSMD. |

---

## 3. iOS architecture

### Real-time path (all on-device, no network)

```
BLE/USB keyboard
  → Core MIDI input port (MIDI 1.0 protocol requested, event-list API)
  → MidiAdapter: parse, map note-on vel 0 → note-off, CC64 pedal, CC120/123 → clear
  → TimestampNormalizer: host time → Int64 µs since session anchor
  → lock-free event queue (no allocation on the MIDI thread)
  → PracticeEngine actor: active-note state + Evaluator (pure, deterministic)
  → state snapshot (published to main thread)
      ├─→ SwiftUI KeyboardStrip  (immediate feedback, latency-gated)
      └─→ NotationBridge → WKWebView/OSMD (cursor + note marks, best effort)
```

### Playback path
`PerformanceGraph` → `Scheduler` (host-time based, read-ahead window ~100 ms) → AVAudioEngine + AVAudioUnitSampler (bundled licensed piano), or optional MIDI out to the keyboard. The count-in clicks are scheduled on the same clock, which anchors beat 0 for rhythm mode.

### Threads and rules
- Do no work on the MIDI callback beyond copying fixed-size events into a preallocated ring buffer.
- The evaluator runs off the main thread, and the UI only reads snapshots.
- WKWebView calls are coalesced to at most one per display frame. Notation highlighting is allowed to lag the keyboard strip, and both are measured (§10).

### Content path (MVP, local only)
Files app or share sheet → `ScoreImport` (validate and parse) → `ImportReport` (supported/unsupported features) → review screen → approved `ScoreRevision` (content-hashed JSON) → library.
The original file is kept unchanged, privately, in the app container.

---

## 4. MVP scope

### In
- One learner and one keyboard, connected over BLE MIDI (USB as reference).
- Import of `.musicxml` and `.mxl` (compressed MusicXML) from Files or the share sheet.
- Library, song detail, practice, session summary and connection screens.
- Demonstration playback, count-in and metronome.
- Passage loop selected by measure numbers. Hand selection: right, left or both.
- **Wait mode** and **rhythm (fixed-tempo) mode**.
- Deterministic replay from recorded event traces, plus golden tests.
- Session summary with one suggested next action.

### Out (explicitly)
Microphone, OMR/PDF/photo import, MIDI-file import (P1), free-tempo following (P1), accounts, sync, licensed pop catalog, AI explanations, *automatically generated* fingering (fingering shown only when a teacher entered it), falling-notes view (P1, as a projection), Android, iPhone, and Mac as an acceptance target. The full Theory curriculum is out of the first slice. Its first units are Phase 2 (§13).

### Supported MusicXML subset v1

| Feature | MVP handling |
|---|---|
| Partwise score, one part with 1–2 staves | **Supported.** If there are several parts, the learner picks one and gets a warning |
| Treble and bass clefs, mid-piece clef changes | Supported |
| Key and time signatures, including mid-piece changes | Supported |
| Notes, chords (`<chord/>`), rests, dots | Supported |
| Voices within a staff (`<backup>`/`<forward>`, up to 2 per staff) | Supported |
| Cross-staff notes (`<staff>` differing from the voice's home staff) | Supported. Hand comes from the voice's home staff, with a manual override |
| Ties | Supported. A continuation is not an expected attack |
| Pickup measure (implicit/incomplete first measure) | Supported |
| Simple tuplets (`<time-modification>`) | Supported |
| Repeat barlines and 1st/2nd endings | Supported and expanded into playback occurrences |
| Tempo (`<sound tempo>` / metronome mark) | Supported, including changes. With no tempo, default ♩ = 80 plus a warning |
| Accidentals, enharmonic spelling | Supported. Written spelling and MIDI pitch are both stored |
| Slurs, dynamics, articulations, fingering text | Rendered and stored, **not scored** |
| Pedal markings | Used for playback only, not scored |
| Grace notes | Rendered and demonstrated, **excluded from scoring**, with a warning |
| Octave shifts (8va/8vb) | **Rejected with a warning** until fixtures from at least two exporters confirm the encoding |
| D.C./D.S./Coda/Fine jumps | **Unsupported.** Warning, linear playback, scoring limited to the linear span |
| Transposing parts (`<transpose>`) | Rejected with a warning |
| Ornaments, tremolos, arpeggio marks | Rendered. Spans containing them are marked **unscored** |
| Timewise MusicXML | Rejected with a warning in the MVP |

Security limits for import: XML external entities disabled (Foundation `XMLParser` with external entity resolution off), MXL total uncompressed size ≤ 20 MB, at most 200 archive entries, path-traversal entries rejected, and a parse timeout.

---

## 5. Module boundaries (Swift packages)

| Package | Responsibility | Depends on | Testable on Linux |
|---|---|---|---|
| `MusicModel` | Rational, Pitch, ScoreNote, Measure, PerformanceGraph, PracticeProjection, schemas, migrations | – | Yes |
| `ScoreImport` | MusicXML/MXL parse → canonical model + ImportReport | MusicModel, ZIP library | Yes |
| `InputContracts` | `PerformanceEvent`, `InputAdapter` protocol, trace (JSONL) reader/writer | MusicModel | Yes |
| `Evaluator` | Wait/rhythm evaluation, pure functions, versioned tolerances | MusicModel, InputContracts | Yes |
| `LessonEngine` | Session state machine, loop and tempo policy, mastery updates, next-action suggestion | Evaluator | Yes |
| `TestFixtures` | Golden scores, expected canonical JSON, event traces, expected evaluations | – | Yes |
| `Difficulty` *(new)* | Feature extraction from a score, transparent difficulty score, reasons (§17) | MusicModel | Yes |
| `TheoryKit` *(new)* | Generates scales, chords, inversions, progressions and intervals in any key, with correct spelling. Exports MusicXML snippets for display (§20) | MusicModel | Yes |
| `ExerciseEngine` *(new)* | Exercise types beyond "play this passage": chord/set answers, ear training, quizzes, technique drills (§20) | Evaluator, TheoryKit | Yes |
| `TechniqueMetrics` *(new)* | Evenness, legato overlap, touch and dynamics, voicing balance, pedal timing from event traces (§19) | InputContracts | Yes |
| `Curriculum` *(new)* | Skill graph, units, lessons, prerequisites, progress and "what next" across both sections (§18) | LessonEngine, ExerciseEngine | Yes |
| `ContentPack` *(new)* | Versioned bundle of lessons, song metadata, fingerings and teacher ratings. Validates content against the skill graph (§21) | MusicModel, Curriculum | Yes |
| `MidiAdapterApple` | Core MIDI ports, BLE pairing UI, disconnect handling, MIDI out to the piano | InputContracts | No (Apple only) |
| `AudioPlayback` | Demonstration through the piano (MIDI out) or AVAudioEngine sampler, scheduler, count-in | MusicModel | No |
| `NotationBridge` | WKWebView + bundled OSMD, ID mapping, highlight messages, also renders theory snippets | MusicModel | No |
| `App` | SwiftUI screens, persistence, settings | all | No |

**Working split:** an AI or cloud session can write and test every package marked "Yes" without hardware. That now covers most of the logic, including all of the theory exercise generation and checking. Everything from `MidiAdapterApple` down needs Xcode on a Mac, the iPad and the Roland.

---

## 6. Data schemas v1

Conventions: `schemaVersion` on every persisted root. Time positions are `Rational` fractions of a whole note, stored as `{"n":Int64,"d":Int64}` with d > 0 and reduced by gcd. Performance times are **Int64 microseconds** relative to a session anchor, with no floating point in the evaluator. Unknown values are explicit `null`.

```swift
struct Rational { let n: Int64; let d: Int64 }            // reduced, overflow-checked

struct ScoreRevision {
  let schemaVersion: Int                // 1
  let id: String                        // content hash (SHA-256 of canonical JSON)
  let parentRevisionId: String?
  let songId: String
  let importEngineVersion: String       // "scoreimport-0.1.0"
  let reviewState: ReviewState          // .needsReview | .approved | .rejected
  let unsupportedFeatures: [ImportWarning]
  let measures: [Measure]
  let notes: [ScoreNote]
  let tempoMap: [TempoChange]
  let createdAt: Date
}

struct ScoreNote {
  let stableId: String          // "m{measureIdx}.s{staff}.v{voice}.e{eventIdx}.p{chordIdx}"
  let measureId: String
  let staff: Int                // 1 = upper, 2 = lower
  let voice: Int
  let writtenStep: Step; let writtenAlter: Int; let writtenOctave: Int
  let midiPitch: Int            // sounding
  let onset: Rational           // within measure, whole-note units
  let duration: Rational
  let tie: TieRole?             // .start | .continue | .stop
  let isGrace: Bool
  let handDefault: Hand         // from home staff of voice
  let handOverride: Hand?
  let sourceLocation: SourceLocation   // part, measure number, note index in XML
}

struct PlaybackOccurrence {
  let id: String                // "{measureId}#{occurrenceIndex}"
  let sourceMeasureId: String
  let occurrenceIndex: Int
  let start: Rational           // absolute position after repeat expansion
  let end: Rational
}

struct ExpectedAttack {         // derived, never persisted as truth
  let id: String                // "{noteStableId}@{occurrenceIndex}"
  let groupId: String           // same absolute onset + same hand selection
  let midiPitch: Int
  let hand: Hand
  let position: Rational
  let timeUs: Int64?            // filled by tempo map in rhythm mode
}

struct PerformanceEvent {
  let seq: Int64                // monotonically increasing per session
  let source: InputSource       // .bleMidi | .usbMidi | .virtual | .replay
  let type: EventType           // .noteOn | .noteOff | .pedal | .allNotesOff | .disconnect | .reconnect
  let pitch: Int?
  let velocity: Int?
  let channel: Int?
  let pedalValue: Int?
  let timeUs: Int64             // host time → µs since anchor
  let rawHostTime: UInt64?
}

struct Evaluation {
  let expectedId: String?
  let observedSeqs: [Int64]
  let classification: Classification   // see §8
  let onsetErrorUs: Int64?
  let excludedReason: ExclusionReason? // .unsupportedSpan | .inputDisconnected | .otherHand | .graceIgnored
}

struct PracticeSession {
  let schemaVersion: Int
  let id: String
  let scoreRevisionId: String
  let passage: PassageSelection  // startMeasure, endMeasure, occurrence-aware
  let hand: HandSelection        // .right | .left | .both
  let mode: Mode                 // .wait | .rhythm
  let tempoPercent: Int          // of score tempo
  let toleranceVersion: String   // "tol-1"
  let evaluatorVersion: String
  let calibrationId: String?
  let traceFile: String          // JSONL
  let startedAt: Date
}

struct Mastery {
  let scoreRevisionId: String; let passageKey: String; let hand: HandSelection
  let tempoBand: Int            // tempoPercent rounded down to 10
  let assisted: Bool            // wait mode or hints shown
  let reliableAttempts: Int; let lastResult: AttemptResult; let lastPracticedAt: Date
}
```

**Event trace (JSONL):** the first line is a header `{traceVersion, appVersion, evaluatorVersion, toleranceVersion, scoreRevisionId, passage, hand, mode, tempoPercent, calibrationOffsetUs, deviceModel, inputName}`, followed by one `PerformanceEvent` per line. Replaying a trace with the same header must give byte-identical `Evaluation` output.

**Persistence (MVP):** content-hashed JSON files for revisions and traces, and a small index for the library, sessions and mastery. Either Codable JSON in P0 or SQLite through GRDB in P1 (explicit migrations). Migration tests come with the first schema change.

The schemas for the Songs and Theory sections (`Skill`, `Unit`, `Lesson`, `Exercise`, `SongMeta`, `DifficultyReport`, `SkillProgress`) are in §21.3.

---

## 7. Screen flows (iPad landscape as the primary layout)

**Top-level navigation** (tab bar): **Songs · Theory · Progress**. Settings and the connection status sit in the toolbar. Theory has a segmented switch at the top: **Piano technique & theory | Music theory**.

1. **First launch:** a one-sentence explanation, then "Connect your piano". Next comes an optional **placement check** (about 5 minutes, skippable, §18.4) that sets the starting level in both sections. No account.
2. **Connection sheet:** lists Core MIDI sources, with a "Pair Bluetooth MIDI…" button that opens the system BLE MIDI pairing controller. Roland-specific hints: set the piano's Bluetooth function to MIDI, and close other apps that might hold the connection. Shows a live note readout, a range check (play the lowest and highest keys), a pedal check (press and release, showing the raw value) and the input health status. A toggle chooses whether demonstrations play through the piano's speakers or the iPad.
3. **Songs library:** ranked by difficulty (§17). Pieces are grouped into levels L1–L6, and within a level ordered by difficulty score. Each card shows title, composer, level, what makes it hard (for example "wide left-hand leaps · 3 sharps"), skills it uses, status badge (*Ready* / *Needs review* / *Unsupported*), progress, and "Resume". Filters: level, skill, style, "Suggested for me". Imported pieces are rated automatically and labeled "estimated".
3a. **Song detail and learning path:** the piece's steps (§17.4), the theory lessons it relates to ("Uses I–IV–V in G: review"), the key and chords, and the start button.
4. **Import review:** the rendered score, a list of warnings with measure links, playback of selected measures, a hand override per voice, and "Approve for practice". Unsupported spans are visibly shaded.
5. **Practice:**
   - Top two-thirds: OSMD notation (1–2 systems) with a cursor on the current group.
   - Bottom third: a native keyboard strip over the calibrated range. Expected keys are outlined, correctly played keys filled, wrong keys marked ✕. Shapes are used as well as color.
   - Controls bar with large targets: ▶ Demo · ● Start/Pause · Hand L/R/Both · Mode Wait/Rhythm · Tempo −5%/+5% · Loop "m. 1–4" (tap to type measure numbers) · input status dot.
   - One feedback line: for example "Measure 3: F♯ missed twice."
6. **Session summary:** measures practiced, tempo, matched/missed/extra counts, a timing histogram (rhythm mode), excluded spans and why, one next action ("Loop m. 3–4 right hand at 70%"), and "Report a recognition problem" (saves the trace).
7. **Settings:** latency calibration, input selection, demonstration route, notation size, note labels on/off, reduced motion, delete song and its traces.
8. **Theory home:** two tracks, each a list of units with lessons, progress rings, and the next recommended lesson. Prerequisites show as "Needs: …" and are never hard-locked (you can always open a lesson).
9. **Theory lesson:** short explanation blocks (text, a keyboard diagram, a notation snippet, play-to-hear), each followed by an exercise that is answered **on the piano** where possible (§20), or by tapping. A lesson ends with a short check and a link to a song that uses the idea.
10. **Technique drill:** a large-number readout for one metric at a time (for example "Evenness: 18 ms spread"), a per-note bar chart after each run, and a single cue ("The 4th finger notes were late"). The drill's limits are always stated on screen ("measures the sound, not your hand position").
11. **Progress:** a skill map across both sections, songs by level, practice time, and technique metric trends. No streak pressure by default.

iPhone is not a design target. Portrait iPad is supported for the Theory section and the library, while Practice asks you to rotate to landscape.

---

## 8. Deterministic evaluation spec (evaluator v1, tolerance tol-1)

### 8.1 Build the expected set
From the approved revision, passage and hand selection:
1. Expand repeats into occurrences, then take the occurrences inside the passage.
2. For each non-grace note, **excluding tie continuations/stops**, create an `ExpectedAttack`.
3. Notes in unsupported or unscored spans are marked `excluded(.unsupportedSpan)`.
4. If hand ≠ both, the other hand's attacks become the **other-hand set**. The app plays them as accompaniment if enabled, and they are never penalized.
5. Group the remaining attacks by identical absolute `position` → **onset groups**, ordered by position.

### 8.2 Input normalization (both modes)
- A note-on with velocity 0 is a note-off.
- CC64 ≥ 64 is pedal down, below 64 is pedal up. The pedal never creates or removes attacks.
- CC120/CC123 or a disconnect clears the active-note state.
- Events from any channel are accepted, and the channel is recorded.
- If a note-on arrives for a pitch already held without a note-off between, treat it as a fresh attack and log a `duplicateNoteOn` diagnostic.

### 8.3 Wait mode
- The cursor sits on the first unsatisfied group. A group becomes **active** at time `tA` (when the previous group completed, or at session start).
- A note-on at time t ≥ tA for pitch p:
  - If p is in the active group and not yet satisfied: mark it satisfied.
  - Else if p matches the other-hand set at or near the cursor: `excluded(.otherHand)`.
  - Else: `wrongNote` (or `octaveError` if p ± 12k is in the group), recorded against the active group. The group does not advance.
- **Fresh-attack rule:** keys held from before `tA` never satisfy a group. Holding C does not satisfy four repeated Cs.
- **Chord policy:**
  - *Strict* (default): all pitches must be struck within `chordSpreadUs = 120 000` of the first satisfying note-on. Otherwise the group resets, and the out-of-window note-ons count as `chordSpreadExceeded`.
  - *Beginner*: any order, no spread limit.
- When all pitches are satisfied, the group completes and the next group activates. Rests between groups need no input. They are shown but never wait.
- **Hint escalation:** after 3 wrong notes on one group, show the note names on the keyboard strip and mark the attempt `assisted`.

### 8.4 Rhythm mode
- **Time map:** beat 0 of the passage is the host time of the first downbeat after the count-in. `timeUs(position)` comes from the tempo map scaled by `tempoPercent`, using integer arithmetic (round half to even at the final µs).
- **Latency compensation:** observed `timeUs − calibrationOffsetUs`. The offset is capped at ±150 000 µs and shown in settings.
- **Matching per pitch:** for each pitch p, take expected attacks Eₚ and observed note-ons Oₚ, both sorted by time. Find an order-preserving matching where |o − e| ≤ `acceptUs = 200 000`:
  1. Maximize the number of matches.
  2. Then minimize Σ|o − e|.
  3. Then prefer the earlier observed event (dynamic programming, O(|Eₚ|·|Oₚ|)).

  One observation can never satisfy two expected attacks.
- **Wrong-pitch pairing:** among the remaining unmatched expected (U_E) and unmatched observed (U_O) attacks, pair greedily by smallest |Δt| ≤ `acceptUs`, with ties broken by lower expected id and then lower seq. Only pair within the same hand range, split at the passage's staff boundary pitch or the override. Pairs are `wrongPitch`, flagged `octaveError` if Δpitch is a multiple of 12.
- **Remaining:** unmatched expected → `missed`, unmatched observed → `extra`. An observed attack that matches the other-hand set → `excluded(.otherHand)`. An observed re-strike during a tie continuation → `extra(reason: tiedContinuation)`.
- **Timing class for matches:**
  - |err| ≤ `onTimeUs = 75 000` → `onTime`
  - err < 0 → `early`
  - err > 0 → `late`
- Releases and durations are **not scored** in v1.

### 8.5 Disconnect and abstention
- On endpoint removal or offline notification: pause immediately, emit `.disconnect`, clear held notes.
- Every expected attack after the **last received event before the disconnect** is `excluded(.inputDisconnected)`. This is the conservative choice: it can forgive genuine misses, but it never invents penalties.
- On reconnect, the learner chooses a measure to resume from. Stale buffered events with timestamps before the reconnect are dropped.

### 8.6 Attempt result and mastery
- An attempt is **reliable-pass** when:
  - all scored expected attacks are matched (wait: satisfied; rhythm: onTime/early/late),
  - extras ≤ max(1, 5% of scored attacks),
  - in rhythm mode, at least 80% are onTime,
  - and excluded attacks are ≤ 10% of the passage.

  If more than 10% is excluded, the attempt is `inconclusive`. It never counts as a pass or a fail.
- **Tempo suggestion:** after 2 consecutive reliable passes without hints, offer +5%. After 3 consecutive failed attempts, offer one of: shorten the loop to the worst 2 measures, −10% tempo, or one hand.
- All thresholds above are **initial values to validate with real learners**, not proven pedagogy.

### 8.7 Versioning
`evaluatorVersion` and `toleranceVersion` are stored with every session. Any change to the rules or defaults bumps a version and must keep the old golden outputs reproducible under the old version, or migrate them explicitly.

---

## 9. Test fixtures

All scores are **engraved by us** from public-domain compositions or written from scratch. Each is exported from at least two notation programs where possible, because MusicXML dialects differ. Each fixture comes with an expected canonical JSON.

| ID | Content | Exercises |
|---|---|---|
| F01 `scale-c-rh` | C major scale, quarter notes, right hand | baseline parse, range |
| F02 `chords-lh` | Block triads in the left hand | onset groups, chord spread |
| F03 `repeated-notes` | Four repeated Cs, then a tied C | fresh-attack rule, ties |
| F04 `pickup-dotted` | 3/4 piece with a pickup, dotted rhythms | implicit measure, rationals |
| F05 `triplets` | Eighth-note triplets against quarters | tuplets, exact rationals |
| F06 `two-voices` | Soprano/alto in one staff using backup/forward | voices not serialized |
| F07 `cross-staff` | RH voice crossing into the bass staff | hand assignment, override |
| F08 `repeats-endings` | ‖: A :‖ with 1st/2nd endings | occurrence expansion |
| F09 `meter-key-change` | 4/4→3/4, G→F major, accidentals | signature changes, spelling |
| F10 `grace-ornament` | Grace notes plus a trill | exclusion, unscored span warnings |
| F11 `minuet-g` | Our engraving of a short public-domain minuet (16 bars) | end-to-end realistic piece |
| F12 `bad-inputs` | XXE payload, zip bomb, path traversal, timewise file, 8va | rejection and warnings |

**Event traces.** Some are synthetic, generated by script. Others are recorded on the real keyboard and labeled as such. Each has an expected `Evaluation` JSON.

| Trace | Expected outcome |
|---|---|
| T01 perfect performance of F11 (rhythm) | all matched, reliable-pass |
| T02 correct melody, wrong bass | RH matched, LH wrongPitch/missed. Not a pass |
| T03 one held C across four repeated attacks (F03) | 1 matched, 3 missed |
| T04 re-strike of a tied note | `extra(tiedContinuation)` |
| T05 octave error in measure 2 | `wrongPitch` + `octaveError` |
| T06 skip measure 3 | that measure missed, later measures still matched (no cascade) |
| T07 many extra notes (mashing) | extras counted, never a pass |
| T08 rolled chord at 300 ms spread | strict: reset, beginner: pass |
| T09 correct notes, half a beat late throughout | all `late` or out-of-window. Not a pass |
| T10 disconnect at measure 5 | m. 5 onward excluded, attempt inconclusive |
| T11 note-on vel 0 used as note-off | parsed as note-off |
| T12 RH-only practice while playing both hands | LH excluded(.otherHand), no penalties |
| T13 restart within a repeat (wait mode) | cursor follows the occurrence, no false skips |

---

## 10. Hardware, latency and quality gates

All targets are **initial, to validate on your devices**. Report results per device and transport.

| Gate | Target | How to measure |
|---|---|---|
| BLE pairing | Pairs through the in-app controller; reconnects after the keyboard power-cycles | Manual checklist, 10 cycles |
| Event integrity | 0 lost, 0 duplicated, 0 stuck notes | Play each key in range once, then 30 s of trills, then 20 pedal cycles. Every note-on has a note-off, and counts match the trace |
| Receipt → keyboard-strip feedback | p95 < 50 ms | MIDI host timestamp to the display-link timestamp of the frame that shows the highlight, logged in a dev build over 500 notes |
| Physical key → visible feedback | Reported, with a target set after Phase 0 | iPhone slow-motion video (240 fps, ~4 ms resolution) filming a key press and the iPad screen together, 30 samples per transport |
| Receipt → notation highlight (OSMD) | p95 < 100 ms (best effort) | Same as the receipt → strip method, through the bridge |
| BLE vs USB timing jitter | Report the inter-onset std-dev difference | Play steady notes to a metronome for 60 s on each transport, compare IOI spread |
| Playback timing | Count-in/demo clicks within ±2 ms of schedule (host clock) | Render-time logging |
| Disconnect | Grading paused at detection, 0 penalties added | T10 on real hardware: switch the keyboard off mid-phrase |
| Deterministic replay | 100% byte-identical evaluations | CI over all traces |
| Golden import | 100% exact match on F01–F11, correct rejections on F12 | CI |

**Output-route caveat:** Bluetooth headphones add output delay to the demonstration and count-in. This does not affect MIDI input latency. Calibration (8 bars of tap-along to the count-in clicks, median offset) is measured per output route and labeled by route.

**Demonstration through the Roland's own sound (preferred):** Roland digital pianos generally accept MIDI input, so sending demonstration notes to the piano gives its real piano tone, needs no sample licensing, and keeps the sound coming from the instrument you play. Things to verify in Phase 0:
- MIDI-out latency and jitter over BLE compared with USB.
- Which MIDI channel the piano's main tone responds to (usually channel 1).
- That app demonstrations do not trigger the app's own input as "played" notes. They shouldn't, because the piano sends what you play and does not echo incoming notes back, but confirm it with a trace.
- Whether "accompaniment hand" playback during one-hand practice sounds good mixed with your playing.

The bundled sampler (§11) remains the fallback when the piano is not connected.

**Technique-metric gates (new, see §19):** every metric must be **repeatable on your Roland**. Play the same scale 10 times as evenly as you can, and the metric's run-to-run spread must be small compared with the differences it reports. A metric that fails this check is hidden, not shown with false precision.

---

## 11. Dependency and license checklist

Record each item before integrating it: exact version/commit, license, maintenance activity, known security issues, minimum OS, binary size, offline behavior, and a replacement path.

| Dependency | Use | License (verify at integration) | Notes |
|---|---|---|---|
| Core MIDI, CoreAudioKit, AVFoundation, WebKit | Platform | Apple SDK | No extra license. Check current MIDI event-list API usage and the Bluetooth permission string requirements |
| OpenSheetMusicDisplay | Notation in WKWebView | BSD-3-Clause | Bundle locally, no CDN. Exclude sponsor/early-access features. Include the license notice |
| ZIP library (e.g. ZIPFoundation) | MXL decompression | MIT (verify) | Enforce the size and entry limits in our code |
| GRDB (P1, optional) | SQLite index with migrations | MIT (verify) | Plain Codable JSON suffices for P0 |
| Piano samples / SF2 | Demonstration sound | **Open item** | A free CC-BY candidate (e.g. Salamander Grand–derived banks) needs attribution, redistribution and size checks. A commercial set needs app-redistribution rights |
| Verovio (fallback only) | Alternative renderer | LGPLv3 | Legal review before any iOS distribution |
| Audiveris, Basic Pitch, MAESTRO | **Not in MVP** | AGPL-3.0 / Apache-2.0 / CC BY-NC-SA | Reviewed later under their own gates |

Pin all Swift Package Manager dependencies with `Package.resolved` committed. No analytics SDKs in the MVP.

---

## 12. Effort and budget

### Effort (planning ranges, not quotes)

| Phase | Experienced iOS engineer | Notes |
|---|---|---|
| 0. Hardware and bridge spike | 1.5–2.5 wks | Adds the OSMD↔native ID-mapping spike to the original Phase 0 |
| 1. MIDI vertical slice (P0) | 4–6 wks | Core packages, about 40% of this, can be built and tested in parallel by an AI session without hardware |
| 2. Usable song tutor (P1) | 3–5 wks | MIDI-file import, persistence, calibration, accessibility, free-tempo follower, **difficulty ranking + song learning paths** |
| 3. Theory engine (new) | 4–6 wks | TheoryKit, ExerciseEngine, TechniqueMetrics, Curriculum, ContentPack, theory screens |
| **Total engineering, Songs + Theory engine** | **≈ 13–20 wks** | Engineering only. Content is costed separately below |

If you are learning Swift while building with AI help, calendar time is **not estimable yet**. Plausibly 2–3× the engineer range, but re-estimate at the end of Phase 0 from actual pace. Microphone and OMR work is excluded, as in the original plan.

### Content effort (new, now the larger cost)
Planning ranges for writer plus teacher time. Calibrate after the first unit is produced.

| Content | Quantity for a first complete release | Effort per item | Total |
|---|---|---|---|
| Starter song library: engraving, phrase steps, teacher fingering, level rating | 24 pieces (4 per level) | 2–4 h | 50–100 h |
| Piano technique & theory lessons, with exercises | ~30 lessons (§18.2) | 3–6 h | 90–180 h |
| Music theory lessons, with exercises | ~36 lessons (§18.3) | 2–5 h (many exercises are generated) | 70–180 h |
| Teacher review and difficulty calibration session | – | – | 15–30 h |
| **Total** | | | **≈ 225–490 h** |

AI can draft the lesson text and exercise definitions. Drafts **do not ship until a teacher has reviewed them** (§21.2).

### Cash (recheck prices at purchase time)
- Mac: already owned, $0.
- Apple Developer Program: about US$99/year, recheck. Optional for a personal prototype, since free provisioning works but apps must be re-signed every 7 days.
- A USB-B to USB-C cable (or a Lightning camera adapter plus a USB-B cable), about US$10–50, for the USB-MIDI reference path.
- Piano samples: $0 if demonstrations go through the Roland. A fallback sampler costs $0 (CC-BY, with attribution) up to a few hundred dollars.
- **No teacher review fee** (§22). Its place is taken by your own and AI research and cross-checking time, which stays inside the content-hours table. The teacher-review hours in that table become cross-checking and self-testing hours.
- **Optional:** 2–4 one-off lessons as technique check-ins (§22.4), at your local or online lesson rate.
- **Cables:** a USB-B to USB-C cable for the iPad Pro (about US$10–20). No adapter needed.
- Repertoire: $0 for public-domain compositions in your own engravings. A licensed pop catalog is a commercial-phase cost, not part of this plan.
- Cloud, servers, OMR: $0 in the MVP.
- Contingency: 30% on engineering and content estimates, as a planning choice.

---

## 13. Refined backlog

### Phase 0: spike (stop/go)

| ID | Task | Done when |
|---|---|---|
| S0-1 | From the FRP-1 owner's manual (Roland support site), confirm Bluetooth MIDI and how to enable it, the USB Computer port, whether it receives MIDI notes (and on which channel), the pedal type in your bundle, and the Key Touch settings | Compatibility note written, and the §1 table updated from "found" to "confirmed" |
| S0-1b | Record traces on the Roland: a scale played 10× evenly, chords at three loudness levels, pedal changes, half-pedal | Raw data for the §19 metric checks |
| S0-2 | Minimal app: pair over BLE, log note-on/off, pedal and timestamps, detect disconnect | Event-integrity gate passes on your device |
| S0-3 | OSMD in WKWebView: load F11, build the stableId → graphical note map, highlight by ID after rotation or resize | Mapping is correct for every note in F01–F11 |
| S0-4 | AVAudioEngine sampler plus count-in on host time, and an optional MIDI-out demonstration to the keyboard | Playback timing gate passes |
| S0-5 | Measure latency on the strip and the notation, BLE vs USB | Numbers recorded |

**Stop/go:**
- If BLE MIDI fails on your keyboard, use USB as the primary input, or check the manual for a supported MIDI route.
- If the OSMD ID mapping is unreliable, evaluate Verovio (with the license review) or switch the MVP to a keyboard/piano-roll view with notation shown read-only.

### P0: vertical slice
- **P0-1 `MusicModel` + `ScoreImport`** for the §4 subset. Done when F01–F12 golden tests pass.
- **P0-2 `InputContracts` + trace I/O + `MidiAdapterApple`.** Done when traces recorded on the device replay in CI.
- **P0-3 `Evaluator`**, wait and rhythm modes per §8. Done when T01–T13 produce the expected evaluations, byte-identical across runs.
- **P0-4 `AudioPlayback` + `NotationBridge`.** Done when cursor, demonstration audio and count-in agree after resize and tempo change.
- **P0-5 `LessonEngine` + screens** for library, practice, summary and connection. Done when someone unfamiliar with the app completes a 4-measure lesson without help.

### P1: song tutor
- **P1-1 `Difficulty`.** Feature extraction and scoring per §17. Done when the teacher-ordering check in §17.3 passes on the starter library.
- **P1-2 Song learning paths.** Generated steps per §17.4, with teacher edits stored in the ContentPack. Done when a learner can go from "never played it" to a full slow play-through by following the steps alone.
- **P1-3 Starter library**, first 12 pieces (L1–L3), engraved and reviewed.
- Also: MIDI-file import with track and hand assignment, persistence index plus migrations, calibration screen, reconnect UX, accessibility pass (VoiceOver labels, Dynamic Type, reduced motion, non-color states), free-tempo follower (bounded alignment), falling-notes projection, delete and export.

### Phase 2b: Theory (new)
- **T-1 `TheoryKit`.** Spelling-correct scales, chords, inversions and progressions in all keys. Done when generated output matches a hand-checked table for all 12 major and 12 minor keys.
- **T-2 `ExerciseEngine`.** The exercise types in §20.1 with deterministic checking. Done when golden traces for every type pass, including deliberate wrong answers.
- **T-3 `TechniqueMetrics`.** Done when the §10 repeatability gate passes on Roland traces from S0-1b.
- **T-4 `Curriculum` + `ContentPack` + theory screens.** Done when the first unit of each track (P1 and M1 in §18) is complete, teacher-reviewed and usable end to end.
- **T-5 Placement check** (§18.4).
- **T-6 Remaining units**, released one unit at a time, each teacher-reviewed.

### P2 (each behind its own gate)
OMR import and review, microphone melody beta, polyphonic spike, licensed catalog and sync, Android, optional technique video clips recorded by the teacher.

---

## 14. Updated prompts

### Coding prompt for the core packages (can run in a cloud or AI session without hardware)
> Create a Swift package workspace with `MusicModel`, `ScoreImport`, `InputContracts`, `Evaluator`, `LessonEngine`, `TestFixtures`, with no Apple UI frameworks, buildable and testable with `swift test` on Linux. Implement the MusicXML subset and schemas from §4 and §6 and the evaluator from §8 exactly, using Rational whole-note positions and Int64 microseconds. Author fixtures F01–F12 and traces T01–T13 with expected JSON, and make every test pass. Do not implement Core MIDI, audio, UI or networking. Report any spec ambiguity as a TODO rather than resolving it silently.

### Coding prompt for the theory and difficulty packages (no hardware needed)
> Add `Difficulty`, `TheoryKit`, `ExerciseEngine`, `TechniqueMetrics`, `Curriculum`, `ContentPack` to the Swift package workspace per §17–§21. TheoryKit must spell every scale and chord correctly in all keys (e.g. F♯ major contains E♯, not F). Exercise checking and technique metrics must be pure, deterministic functions of the event trace and the exercise definition, and each must have golden tests with deliberately wrong answers. Lesson text is content, not code: load it from a ContentPack and mark anything unreviewed `draft`. Do not write lesson prose yourself beyond placeholder stubs.

### Prompt for the app shell (needs a Mac with Xcode and the device)
> Using the core packages, build the SwiftUI app for Phase 0 tasks S0-2 to S0-5 and then P0-4 and P0-5. Use Core MIDI's current event-list API requesting the MIDI 1.0 protocol, CoreAudioKit's Bluetooth MIDI pairing controller, AVAudioEngine with host-time scheduling, and OSMD bundled in a WKWebView. Log the latency measurements in §10. Do not claim hardware validation until the gates are measured on the Roland piano and the iPad.

---

## 15. Unverified assumptions (TODO)
- The Roland FRP-1's features come from retailer and third-party listings only. Bluetooth MIDI is well supported. USB-MIDI, MIDI input, the pedal type and Key Touch behavior must be confirmed from the manual and by testing (S0-1).
- The iPad Pro (M4) iPadOS version at the start of development sets the minimum OS.
- There is no teacher. Content quality depends on the §22 process. Technique guidance carries the most risk, and nothing in the app can check posture or hand position.
- The difficulty-feature weights (§17.2) and level boundaries are initial guesses until calibrated against teacher rankings.
- Every technique metric (§19) must pass the repeatability gate on the Roland before it is shown.
- The current Core MIDI API surface: event-list/UMP input ports, the Bluetooth pairing controller, and which Info.plist Bluetooth usage strings are needed. Verify against the current SDK in S0-2.
- How Core MIDI converts BLE MIDI packet timestamps to host time, and the resulting jitter. Measure in S0-5.
- That OSMD's graphical model can be mapped deterministically to our stableIds across exporters (S0-3).
- How 8va/8vb is encoded across exporters (kept rejected until fixtures confirm).
- License and size of the chosen piano sample set.
- All thresholds in §8 and §10 are initial values and need validating with real learners and devices.
- The effort ranges assume an experienced iOS engineer. Re-estimate after Phase 0.

---
---

# Part 2: Learning content (Songs and Theory)

## 16. Product structure and learner

### 16.1 Who it is for
Advanced beginners who:
- read both clefs, if slowly;
- can play basic chords (for example I–IV–V) with both hands;
- want to learn real pieces step by step, play with sound technique, and understand *why* the music works.

The app's job is to carry them from about level L1 to early intermediate (L6 in §17.1).

### 16.2 Design principles
1. **Theory is always tied to playing.** Every theory lesson ends at the piano and links to a song that uses the idea. Every song links back to the theory it uses.
2. **The Songs list is ranked by difficulty**, and the app explains *what* makes each piece hard. It never shows just a number.
3. **Technique feedback is honest.** The app comments only on what MIDI actually measures (§19) and says plainly what it cannot see.
4. **One shared skill map.** Songs, technique lessons and theory lessons all tag the same skills, so progress in one section informs suggestions in the others.
5. **Nothing is hard-locked.** Prerequisites are advice. An adult learner can open anything.

---

## 17. Songs section: difficulty ranking and step-by-step learning

### 17.1 Levels
These are the app's own levels, not an exam board's grades. Teacher review sets the final boundaries.

| Level | Typical demands |
|---|---|
| **L1 Consolidate** | Melody plus block or simple broken chords; keys with up to 1 sharp or flat; quarters and eighths; few hand-position shifts |
| **L2** | Simple broken-chord and Alberti patterns, dotted rhythms, position shifts, keys up to 2 sharps/flats, first use of pedal |
| **L3** | Legato (syncopated) pedaling, chord inversions in the left hand, minor keys, syncopation, first two-voice writing in one hand |
| **L4** | Scale passages, sixteenths, shaping dynamics, voicing a melody over an accompaniment |
| **L5** | Rhythmically independent hands, larger leaps, up to 4 sharps/flats, simple ornaments, two-voice counterpoint |
| **L6 Early intermediate** | Sustained independence, faster figuration, wider dynamic and pedal control |

**Candidate starter repertoire.** All are public-domain compositions, engraved by us. Level placement is *indicative only*, for the teacher to confirm:
- **L1:** our own two-hand arrangements of traditional tunes, and a two-hand "Ode to Joy" arrangement.
- **L2:** selected short pieces by Türk and Gurlitt.
- **L3:** Minuet in G (Petzold, BWV Anh. 114); Schumann "Melody" Op. 68 No. 1.
- **L4:** Musette in D (BWV Anh. 126); Schumann "Soldiers' March" Op. 68 No. 2; Burgmüller Op. 100 No. 1.
- **L5:** Burgmüller "Arabesque" Op. 100 No. 2; Tchaikovsky "Old French Song" Op. 39; Satie Gymnopédie No. 1.
- **L6:** Clementi Sonatina Op. 36 No. 1 (first movement); Chopin Prelude Op. 28 No. 4; Schumann "The Wild Horseman" Op. 68 No. 8; Grieg "Arietta" Op. 12 No. 1.

A composition being in the public domain does not make every edition or scan free to use. Engrave from the composition yourself, or use an edition whose license allows it, and record the source (§21.2).

### 17.2 Computed difficulty (`Difficulty` package)
Features are computed from the canonical score at the piece's target tempo, per hand where relevant:

| Feature | How it is measured |
|---|---|
| Note density | Attacks per second, 90th percentile over 2-bar windows |
| Rhythmic complexity | Smallest subdivision, tuplets, off-beat onsets per bar, dotted figures |
| Hand independence | Share of onsets where the hands' rhythms differ |
| Chord load | Maximum and mean simultaneous notes per hand |
| Stretch | Widest simultaneous interval per hand. More than an octave is flagged |
| Leaps | 90th-percentile jump between consecutive onsets per hand, in semitones per second available |
| Position shifts | Count of hand-window moves larger than a fifth |
| Key and accidentals | Key-signature accidentals, plus chromatic accidentals per bar |
| Voices per hand | Maximum simultaneous voices in one staff |
| Pedal | Pedal markings and changes per bar |
| Range and length | Total span, and the number of bars after repeats (low weight) |

How the features become a ranking:
- Each feature is mapped to 0–1 with piecewise-linear thresholds.
- The difficulty score is a **weighted sum with non-negative weights** (weights v1 are initial guesses).
- The report gives the **top 3 contributing features** as plain reasons, plus the **hardest 2–4-bar windows**, which the learning path uses (§17.4).

**Ranking rule:**
- Bundled songs: the teacher's level is authoritative, and the computed score orders songs *within* a level.
- Imported songs: the computed score assigns an *estimated* level, using thresholds calibrated on the bundled set.
- Learners can mark a piece "felt too hard" or "too easy". This is logged for recalibration and never silently changes rankings.

### 17.3 Calibration gate
- The teacher independently ranks the starter set.
- Target (initial): Spearman ρ ≥ 0.75 between the computed and teacher rankings, measured on pieces held out from weight fitting.
- Weights are fitted with a simple, constrained, explainable model. No black-box model.
- If the target is not met, the library is ordered by teacher rank only, and computed scores appear only for imports, labeled "rough estimate".

### 17.4 Step-by-step learning path for a song
This is generated from the score and phrase markup, and the teacher can edit it in the ContentPack.

1. **Get to know it:** listen to the demonstration on the Roland. See the key, meter, form (for example A–B–A) and the chords used. Chord symbols and Roman numerals come from **teacher-entered harmony**. For imports the app shows "harmony not analyzed" rather than guessing.
2. **Prepare:** links to the theory and technique lessons for the piece's skills, plus a warm-up built from the piece (its key's scale, and its hardest left-hand pattern as a drill).
3. **Phrase by phrase** (2–4 bars, taken from teacher markup or split automatically at rests and cadences): right hand in wait mode → left hand in wait mode → hands together in wait mode → hands together in rhythm mode at 60%, then 80%.
4. **Join:** phrase 1+2, then the whole section, then the whole piece.
5. **Hardest bars:** the windows found in §17.2 get extra loops and a slowed tempo step.
6. **Musical layer, once the notes are secure:** dynamics, voicing and pedal, using the technique metrics (§19).
7. **Perform and recall:** play the whole piece with no hints. A spaced recall check is scheduled for the next day.

A step is passed using the rules in §8.6. The learner can skip any step.

---

## 18. Theory section: curriculum

### 18.1 Lesson shape
Each lesson takes about 10 minutes and follows **explain → hear → play → check → use it in a song**. Units and lessons form a skill graph with prerequisites, and these can cross tracks. For example, triad inversions (M5) come before smooth left-hand chord changes (P3).

### 18.2 Track 1: Piano technique & theory (about 30 lessons)

| Unit | Content | Measured on the piano |
|---|---|---|
| P1 Setup and healthy playing | Bench height, posture, hand shape, relaxation, arm weight, when to stop | Self-check list only (not measurable), plus a baseline evenness drill |
| P2 Scales and fingering | Thumb-under and crossing, standard major and minor fingerings, hands separately then together, 1–2 octaves | Evenness of timing and tone, bumps at the crossings |
| P3 Chords on the keyboard | Triad shapes, inversions, smooth I–IV–V–I voice-leading in close position | Correct chord and inversion, hand-to-hand sync |
| P4 Broken chords and arpeggios | Alberti bass, broken-chord patterns, 2-octave root-position arpeggios | Evenness, tempo stability |
| P5 Touch and articulation | Legato, staccato, two-note slurs | Legato overlap, staccato length |
| P6 Dynamics and voicing | Controlling loudness levels, melody over accompaniment | Loudness target bands, balance between hands |
| P7 Pedaling | Why and when, legato (syncopated) pedal, clearing harmonies | Pedal timing relative to chord changes |
| P8 Playing from chord symbols | Lead sheets, left-hand patterns (block, root–fifth, broken, ballad arpeggio) under a right-hand melody. Builds directly on the learner's existing chord skill | Correct chords, pattern rhythm |
| P9 Reading fluency | Grand-staff landmarks, reading by interval, generated sight-reading at the learner's level | Wait-mode accuracy and speed |
| P10 How to practice | Chunking, slow practice, stepping up the metronome, hands-separate strategy | Practice-log based |

### 18.3 Track 2: Music theory (about 36 lessons)

| Unit | Content |
|---|---|
| M1 Rhythm and meter | Note values, simple and compound meter, dots, ties, syncopation, with tap-the-rhythm exercises |
| M2 Intervals | Number and quality, by sight, by ear, on the keys |
| M3 Major keys | Scale construction, key signatures, circle of fifths |
| M4 Minor keys | Natural, harmonic and melodic minor; relative and parallel keys |
| M5 Triads | Qualities, building on any note, inversions, chord symbols |
| M6 Seventh chords | maj7, 7, m7, m7♭5, dim7 |
| M7 Diatonic harmony | Roman numerals, tonic/subdominant/dominant function, common progressions (I–IV–V–I, I–V–vi–IV, ii–V–I) |
| M8 Cadences and phrases | Authentic, plagal, half and deceptive cadences; phrase structure |
| M9 Melody | Non-chord tones: passing, neighbor, suspension |
| M10 Form | Binary, ternary, rondo, verse–chorus, applied to pieces in the library |
| M11 Ear training | Intervals, chord qualities, progressions, playing back short melodies by ear |
| M12 Beyond the key | Secondary dominants, simple modulation (stretch unit) |

### 18.4 Placement check (optional, about 5 minutes)
- Play the C, G and F major scales hands together (optional).
- Play I–IV–V–I in C and G, with inversions if known.
- Read and play 4 short generated passages of rising level, in wait mode.
- Answer 6 quick questions on key signatures, intervals and chord quality.

The result suggests a starting song level and a starting unit in each track. The learner can always override it.

### 18.5 Review
Learned skills come back for short reviews on a simple, deterministic schedule (Leitner boxes: 1, 3, 7, 14, 30 days). A failed review moves the skill back one box.

---

## 19. Technique feedback: what MIDI can and cannot tell you

### 19.1 Measurable from your Roland's MIDI

| Metric | Definition (from the event trace) | Used in |
|---|---|---|
| Timing evenness | Spread (standard deviation) of onset errors against a steady target, in ms. Also per scale degree, to locate a consistent "bump" | P2, P4 |
| Thumb-crossing bump | Onset delay and velocity jump at the notes right after a crossing. Crossing points come from **teacher-entered fingering** | P2 |
| Tone evenness | Spread of velocities across a run | P2, P4 |
| Legato | Overlap = next note-on minus previous note-off. A small overlap is legato, a gap is detached, a large overlap is blurred | P5 |
| Staccato | Ratio of key-held time to written duration | P5 |
| Dynamic control | Velocity inside a target band; how steadily velocity rises in a crescendo | P6 |
| Voicing balance | Mean velocity of the melody minus mean velocity of the accompaniment | P6, songs |
| Pedal timing | CC64 release and press relative to the attack of a new harmony. Pressing after the attack is a correct legato pedal; holding through a change is a blur. Harmony changes come from teacher-entered harmony | P7, songs |
| Hand synchronization | Spread of chord onsets between the hands, in ms | P3, songs |
| Tempo stability | Local tempo drift across a run | P2, P4, songs |

**Rules:**
- **Velocity depends on the instrument.** Your Roland's **Key Touch setting** changes how hard you must play for a given velocity. Velocity metrics are therefore relative to *your piano and touch setting*, which calibration records. They are never compared across instruments, and velocity (0–127) is not decibels.
- Every metric must pass the **repeatability gate** in §10 before it is shown, and it is shown with its normal run-to-run spread.
- **One cue at a time** (for example "the notes after your thumb crossing are about 25 ms late"). There is no single combined "technique score".
- All target bands (for example legato overlap of about 0–40 ms) are initial values for the teacher to set.

### 19.2 Not measurable, and how the app handles it
- **Not measurable:** posture, wrist height, finger curvature, tension, **which finger you used**, arm weight, pain.
- **What the app offers instead:** teacher-written explanations and self-check lists. Later (P2), an optional self-review video recorded on the iPad camera, kept on the device and not analyzed. The app also says plainly: "This feedback is about the sound you made, not about your hand position. A teacher can check what the app can't see."
- **Pain:** if playing hurts, stop. This message is visible in P1 and in Settings.

---

## 20. Exercises

### 20.1 Exercise types (all checked deterministically by `ExerciseEngine`)

| Type | What the learner does | How the answer is checked |
|---|---|---|
| PlaySequence | Plays a passage | The evaluator in §8 (wait or rhythm mode) |
| PlayChord | "Play E minor, first inversion, left hand" | The pitch-class set must match; the bass note's pitch class is checked if an inversion is required; octave free unless specified; hand range enforced; all notes held together within the chord spread; extra notes are wrong |
| PlayProgression | "Play I–IV–V–I in G with smooth voice-leading" | A sequence of PlayChord checks, plus an optional limit on how far each voice moves |
| PlayScale / Arpeggio | A scale or arpeggio at a set tempo | Correct notes (sequence), and optionally technique-metric thresholds from §19 |
| EarTraining | The app plays an interval, chord or melody on the Roland, and the learner answers by playing it back or tapping a choice | Answers played on the keys accept any octave unless exact pitch is the point |
| NameIt | Multiple choice, tap on the staff, or tap on the keyboard | Exact match |
| TapRhythm | Tap any key in rhythm | Onset matching only, pitch ignored |
| SightRead | Plays a generated passage at the learner's level | PlaySequence on generated content |

**Generators:** the parameters are keys, clefs, ranges, inversions and rhythm vocabulary. A generator gives unlimited practice from a small amount of content. Each one uses a **seeded random number generator**, and the seed is saved in the trace so any result can be replayed exactly.

### 20.2 Spelling
`TheoryKit` spells notes by letter-and-accidental arithmetic (F♯ major contains E♯; the 3rd of B♭ minor is D♭). MIDI cannot carry spelling, so spelling is only tested on screen. Answers played on the keys are checked by pitch.

### 20.3 Fixtures for the theory engine (additions to §9)

| ID | Case | Expected result |
|---|---|---|
| TH01 | E minor in root position when first inversion was asked | Wrong (inversion) |
| TH02 | Correct triad plus one extra note | Wrong (extra note) |
| TH03 | Synthetic scale with a known 20 ms onset spread | Metric reports 20 ± 1 ms |
| TH04 | Legato pairs with known overlaps | Exact overlap values |
| TH05 | Pedal pressed *before* the new chord's attack | Flagged as a blur |
| TH06 | Accompaniment louder than the melody | Voicing reversed |
| TH07 | Ear-training answer an octave higher | Accepted when octave is free |
| TH08 | Spelling table for all 24 major and minor keys | Matches a hand-checked reference exactly |
| TH09 | Same generator seed run twice | Identical exercise |

---

## 21. Content: production, review and data

### 21.1 ContentPack layout
The pack is bundled with the app and updated by app release. There is no server.
```
content/
  manifest.json          # contentVersion, schemaVersion
  skills.json            # skill graph
  units/*.json
  lessons/*.md           # prose + block references
  exercises/*.json
  songs/<id>.musicxml
  songs/<id>.meta.json   # level, teacher rank, phrases, fingering, harmony, skills, rights
```

### 21.2 Review workflow and AI's role
- Every lesson, exercise, fingering and song record has `reviewState`: `draft` → `teacherReviewed` → `published`. Release builds show only `published` content. Development builds show drafts with a banner.
- **AI may** draft lesson prose, propose exercise parameters, and suggest difficulty tags and phrase splits.
- **AI may not** be the source of record for fingerings, harmony analysis or level placement, and it is never the runtime judge of a performance.
- **Rights record per song:** the composer and their death year, the edition or source used, the engraver (us), the license, and notes. Lesson text and diagrams are our own work.

### 21.3 Schemas (v1)
```swift
struct Skill { let id: String; let track: Track; let title: String; let prerequisites: [String] }
enum Track { case pianoTechnique, musicTheory, repertoire }

struct Unit { let id: String; let track: Track; let order: Int; let lessonIds: [String] }

struct Lesson {
  let id: String; let unitId: String; let title: String; let estMinutes: Int
  let blocks: [LessonBlock]; let skillIds: [String]
  let reviewState: ReviewState; let contentVersion: String
}
enum LessonBlock {
  case text(markdown: String)
  case keyboardDiagram(pitches: [Int], labels: [String]?)
  case notation(snippet: SnippetSource)        // MusicXML file or TheoryKit generator
  case listen(sequence: [ScheduledNote])       // played on the Roland
  case exercise(id: String)
  case songLink(songId: String, measures: ClosedRange<Int>?)
}

struct Exercise {
  let id: String; let type: ExerciseType; let params: ExerciseParams
  let passRule: PassRule; let skillIds: [String]; let generatorSeed: UInt64?
}

struct SongMeta {
  let songId: String; let level: Int; let teacherRank: Int?
  let difficulty: DifficultyReport; let phrases: [MeasureRange]
  let fingering: [String: Int]?               // ScoreNote.stableId → finger, teacher-entered only
  let harmony: [HarmonySpan]?                 // teacher-entered Roman numerals / symbols
  let skillIds: [String]; let rights: RightsRecord; let reviewState: ReviewState
}

struct DifficultyReport {
  let version: String; let score: Double; let estimatedLevel: Int
  let features: [String: Double]; let topReasons: [String]; let hardestWindows: [MeasureRange]
}

struct SkillProgress {
  let skillId: String; let state: SkillState    // .new | .learning | .secure
  let evidence: [EvidenceRef]; let reviewBox: Int; let nextReview: Date?
}
```

### 21.4 Recommended order of work for Part 2
1. Build the skill graph and the levels first, as one page reviewed with a teacher.
2. TheoryKit, then ExerciseEngine (no hardware needed).
3. Engrave the first 12 songs (L1–L3) with teacher fingering and harmony, then run the difficulty calibration.
4. Produce units P1–P3 and M1–M3 completely and test them with 2–3 advanced beginners.
5. Expand only after real learners show they can play better *away from the app*.

---

## 22. Working without a piano teacher (new in v3)

This section **overrides** every "teacher-reviewed", "teacher-entered" and "teacher rank" step earlier in the document.

### 22.1 Principle
Teacher authority is replaced by four things:
- **verifiable sources**;
- **automated checks** in code;
- **honest labels** in the app;
- **testing on yourself**.

Optional spot-check lessons (§22.4) cover the one gap these cannot: what your hands are doing.

### 22.2 By type of content

| Content | Risk without a teacher | What replaces the teacher | Label shown in the app |
|---|---|---|---|
| **Music theory facts** (M track) | Low | Every example and quiz answer is **computed by TheoryKit**, never typed by hand. Prose is cross-checked against ≥ 2 reputable references, for example open music-theory textbooks (verify each one's license before quoting) | None once cross-checked |
| **Scale and arpeggio fingerings** | Low–moderate | Standard fingerings are widely published and largely consistent. Take them from ≥ 2 references and show disagreements as alternatives | "Standard fingering" |
| **Fingerings in pieces** | Moderate | Copy the editorial fingering from a **public-domain edition** (cite the edition), or show none. A computed fingering suggestion is a P2 research item. All fingerings are editable, and your edits are saved | "Edition fingering (source)" / "Your fingering" |
| **Harmony analysis** (Roman numerals, chord symbols) | Moderate | An AI draft, plus an **automated check**: the chord's notes must account for the notes on strong beats, and mismatches are flagged for you to resolve. For well-known pieces, compare with published analyses | "Analysis" |
| **Levels and ranking** | Moderate | **Anchors:** the grade at which published graded piano syllabi (exam-board lists) place a piece, using the listing as a fact only, without copying any exam material. Then the computed score (§17.2). Then your own rating after each song | "Level (anchored)" / "Level (estimated)" |
| **Technique guidance** (P track) | **Highest** | Limited to conservative, widely agreed basics, each claim with a cited source (see 22.5). No remedial diagnosis. The app focuses on what MIDI measures (§19). Self-video review moves up from P2 to P1 | Always shows: "The app hears the result, not your hands" |
| **Grading and exercise answers** | Low | Deterministic code with golden tests (§8, §20). No human review needed | – |

### 22.3 Changes to the review workflow (replaces §21.2)
- States: `draft` → `crossChecked` → `published`.
- `crossChecked` requires all three of:
  1. `sourceRefs`: ≥ 2 sources for facts and standard fingerings, or 1 named edition for piece fingerings;
  2. all automated checks pass (TheoryKit validation, the harmony check, golden tests);
  3. **self-test**: you completed the lesson or song on the FRP-1, and noted anything confusing.
- AI drafts are always `draft`. **AI output is never accepted as a source.**
- Schema additions: `sourceRefs: [SourceRef]` and `label: ContentLabel` on `Lesson`, `Exercise` and `SongMeta`. `SongMeta.teacherRank` becomes `anchorGrade: AnchorGrade?` (exam board, grade, syllabus year) plus `userRatings: [Int]`.

### 22.4 Optional technique check-ins
MIDI cannot see posture, tension or fingering, and no process in this plan replaces a trained eye. The recommendation is **2–4 single lessons** (in person or online), each used as a spot check, not as an ongoing teacher relationship. Suggested timing:
1. After units P1–P2 (setup, scales, thumb crossing).
2. When you reach song level L3 (pedaling, chord changes).
3. Optionally at L5.

Bring the app's technique metrics and your self-videos to each one. If you skip these, the app still works: it keeps technique guidance conservative and relies on the self-check lists.

### 22.5 Technique guidance kept to conservative basics
The P1 content is limited to widely agreed points, each with a source:
- bench height and distance so the forearms are roughly level with the keys;
- relaxed shoulders, a natural finger curve, and a wrist that neither collapses nor rises;
- using arm weight rather than finger force alone;
- short, focused practice sessions;
- **stop if anything hurts.**

The app makes no claims about curing tension or injury.

### 22.6 Testing with real learners
- You are the first learner, and your notes on what was confusing are part of `crossChecked`.
- If possible, recruit 1–2 other advanced beginners to try units P1–P3 and M1–M3. They test **clarity**, not correctness.
- The app has a "This lesson was confusing / seems wrong" button that saves a note for you to review.

### 22.7 Effect on effort and the plan
- **Content hours:** the totals stay at roughly 225–490 h. Teacher-review time is replaced by research and cross-checking time, which may run **10–20% higher**, because finding and comparing sources is slower than asking an expert.
- **Calibration gate (§17.3):** "Spearman ρ ≥ 0.75 against the teacher's ranking" becomes **ρ ≥ 0.75 against anchor grades**, for pieces that have one. Your own ratings are tracked as a second signal and only change the order when you confirm it.
- **§19:** thumb-crossing points come from standard or edition fingering. Where a piece has no fingering, that metric is turned off.
- **§17.4 step 1:** harmony shown is `crossChecked` analysis, labeled "Analysis".
- **§21.4 step 1:** the skill graph and levels are checked against anchors and ≥ 2 references, not a teacher.
