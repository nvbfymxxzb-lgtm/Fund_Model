# Piano tutor app
## Product and engineering build plan
Prepared for Arie Blum | November 13, 2026

A song-first piano teacher that connects to a keyboard, follows your playing, and turns supported scores into step-by-step practice. This is a planning and handoff document, not a tested implementation or a claim of universal song support.

## 1. The recommendation

Build the smallest trustworthy learning loop first: import a correct MusicXML score, connect a MIDI keyboard, choose a short passage, hear a demonstration, play it slowly, receive accurate feedback, and repeat until it feels easier. Then add scanned-sheet recognition and microphone listening as separate capabilities. Keep the final ambition intact, but do not make the entire product depend on solving every recognition problem at once.

The essential distinction is between three jobs:

- **Know the intended music.** Obtain a structured score, recognize an uploaded sheet, or transcribe an authorized recording into an editable arrangement.
- **Know what you played.** Read MIDI events or infer piano notes from microphone audio.
- **Teach the difference.** Follow your place, diagnose specific mistakes, choose manageable practice, and show progress without blaming recognition errors on you.

MIDI is the preferred first input because it provides symbolic performance events rather than requiring acoustic inference. Bluetooth MIDI is a transport for those events, not ordinary Bluetooth speaker/headphone audio. Native Apple and Android platforms document MIDI support; browser support is less uniform, particularly Safari. [S1-S5]

**Recommended sequence:** MIDI learning loop → structured-score library → reviewed sheet-photo import → single-note microphone lessons → validated polyphonic microphone following → broader song discovery and optional recording transcription.

Do not start by training a new transcription model, licensing a huge catalog, building a social network, or adding an AI chat persona. None is necessary to prove that the app can help you learn one song.

## 2. What is fixed, assumed, and still open

### Confirmed request

You want an app similar in purpose to Simply Piano: teach piano songs, connect to your keyboard over Bluetooth or listen to notes, allow song selection or sheet-music upload, and provide a very comprehensive plan that another app can refine. Similar purpose does not mean copying its branding, code, screen designs, recordings, exercises, or catalog.

### Working assumptions, not requirements

- Start with one learner and one piano/keyboard, with personal use before any commercial launch.
- Prioritize correct feedback over an impressive demo.
- First supported repertoire is ordinary solo-piano notation, not orchestral reductions, handwritten manuscripts, or arbitrary recordings.
- Practice should work locally once a supported score is ready. Cloud processing may assist imports, but must not sit in the live feedback loop.
- A tablet or laptop may be more comfortable for reading, but no target device has been selected.

### Decisions before implementation

1. Keyboard make/model, key count, available ports, and whether its Bluetooth is MIDI, audio, or both.
2. Actual target devices and OS versions: iPhone/iPad, Android, Mac/Windows, or browser.
3. Personal prototype or commercial product; launch jurisdictions and intended age range.
4. Coding experience, available engineering help, budget ceiling, and deadline.
5. The app you will use to refine or build this: document assistant, web app builder, or a coding environment with native-device access.
6. Initial song examples, notation-reading level, and preference for sheet music, falling notes, or both.

These questions should change implementation choices, not block planning. Do not purchase an adapter or commit to a framework before checking the keyboard manual and testing the actual device.

## 3. Capability ladder: retain the ambition honestly

**Level A: structured music plus MIDI.** MusicXML/MXL provides notation; MIDI files provide note timing but may lack reliable notation and hand assignments. The learner gets loops, hands-separate work, wait-for-note mode, metronome, playback, timing feedback and progress. First release candidate.

**Level B: printed sheet upload.** PDF, photo or scan is converted by optical music recognition (OMR), then reviewed and corrected before use. The scan itself is not a playable lesson. Audiveris explicitly describes recognition errors and a correction workflow. [S7]

**Level C: microphone, single notes.** Teach melody or hands-separate passages in a quiet room. Detect attacks and pitch, allow uncertainty, and avoid claims about complex chords or exact note release.

**Level D: microphone, polyphonic piano.** Follow two-handed piano with chords and sustain on tested devices and acoustic conditions. This is an audio-ML and alignment project, not an extension of a simple frequency detector. Basic Pitch and Onsets and Frames are candidate references, not proof of reliable live teaching. [S6, S10]

**Level E: broad song selection.** Search an authorized library or the user's private collection, distinguish arrangements and difficulty, and support upload when no playable score is available. A title match is not a score and not a rights grant.

**Level F: authorized audio-to-lesson import.** Convert an isolated piano recording into a draft, then correct rhythm, voices, hand allocation and notation. Full commercial mixes may require separation and arrangement work, with new quality and rights risks. Treat this as later research.

Every song should visibly state its status: ready to learn, import needs review, listening beta, or unavailable. Never silently replace the requested arrangement with a different one.

## 4. Define “any song” as an intake promise, not a guarantee

The app should let you ask for any song. It should not promise that it already has a legal, accurate, teachable arrangement of every song.

### Resolution order

1. Search the approved catalog and your private imported library.
2. Ask which arrangement/version you mean: original piano, easy piano, melody only, or another key.
3. If unavailable, offer MusicXML/MXL import first, MIDI second, then PDF/photo with review.
4. Later, offer transcription of an authorized solo-piano recording, labeled draft.
5. If no supported source exists, explain the gap and allow manual entry or an outside arrangement, rather than inventing notes.

Track three independent states: **source availability**, **musical correctness**, and **permission for the intended use**. One does not imply another.

MusicXML preserves more score information than a plain performance event file, but import still needs a supported-feature contract. MusicXML 4.0 is a published W3C Community Group report, not a W3C Recommendation. [S8]

For MIDI imports, show a piano roll if quantization and staff reconstruction are uncertain. Let the learner choose tracks and hand assignments. Do not infer clefs, fingering, exact spelling or score rhythm with false certainty.

For simplified arrangements, preserve the original separately. Label omitted notes, changed key and changed rhythm. Prefer teacher-reviewed simplifications. A model-generated arrangement is not automatically playable, pedagogically sensible, or licensed.

Acceptance example: searching an unavailable song returns useful import options and never claims to have produced a verified score. Searching a title with three arrangements requires an explicit selection before practice begins.

## 5. Platform decision and recommended stack

### Option 1: native on your actual primary device

If you mainly use an iPad/iPhone, favor a native Apple first build: Swift/SwiftUI, Core MIDI for performance input, and a native audio capture/processing layer. Apple documents BLE MIDI discovery through CoreAudioKit and access as ordinary MIDI devices after connection. Confirm current permissions and supported deployment versions in a hardware spike. [S1, S2]

If Android is your primary device, use Kotlin/Compose with Android MIDI and a native audio path. Android documents USB, BLE and virtual MIDI transports, with MIDI capability dependent on device support. Check `android.software.midi` and test the actual hardware. [S3]

**Best fit:** reliable instrument interaction on a known mobile device. Tradeoff: a second platform needs a separate port or well-maintained shared abstractions.

### Option 2: web-first proof of concept

Use TypeScript, React, Web MIDI where supported, Web Audio, and a score renderer such as OpenSheetMusicDisplay (OSMD). Good for a fast editable prototype on a verified desktop/browser combination. MDN documents secure-context and permission requirements for Web MIDI and microphone capture. Current compatibility evidence does not support treating Safari as a native Web MIDI target. Do not assume another iPhone browser solves that constraint. [S4, S5, S12, S13]

**Best fit:** a web-capable coding app and a learner willing to use the tested browser. Tradeoff: browser/device restrictions and more work to reach native mobile MIDI.

### Option 3: cross-platform shell plus native adapters

React Native or Flutter is a candidate, not a verified shortcut. Prove BLE discovery, timestamps, permissions, audio capture and recovery through a small native bridge before choosing it. Inspect plugin maintenance, licenses and physical-device behavior. Keep rendering and teaching logic separate from input adapters.

**Default decision rule:** build for the device you own, not for all devices. If the refinement app only generates websites, use it for screens, shared types and the web spike, not as evidence that it supports native Bluetooth/audio.

## 6. The core learning journey

### First launch

Explain the app in one sentence. Ask for the preferred learning view and rough experience level. Offer “Connect keyboard,” “Use microphone,” and “Try a sample without an instrument.” Do not require an account for a local personal prototype.

### Instrument setup

Identify the input, show live notes, run calibration, and confirm the keyboard range. If microphone confidence is poor, offer a quieter-room check or MIDI, not a failing grade. Save the device profile, not raw room recordings by default.

### Choose music

Show title, arranger, difficulty estimate, length, source, import status and supported input modes. Preview the score and audio. Imported material goes through review before it can be scored.

### Start practice

Choose a phrase, hand, tempo, and mode. Demonstrate once. Give a count-in. Keep the current measure, upcoming notes and input status visible. The learner should not have to read a dense dashboard while playing.

### Feedback and next step

Use specific feedback: “The F-sharp in measure 4 was missed twice,” rather than “Bad performance.” Separate pitch, timing, continuity and listening confidence. Suggest a short loop, slower tempo or hands-separate work. Offer an unscored replay if the detector was unreliable.

### End session

Summarize practiced measures, tempo, reliable errors and one next action. Show the difference between completing a guided loop and independently playing a passage. Allow “Resume last practice” directly from the library.

A useful first success is learning four measures more reliably in ten minutes. Streaks and gamification are optional, and must not hide whether learning actually happened.

## 7. Connection and hardware requirements

Create one normalized input interface with separate implementations for USB MIDI, BLE MIDI, browser MIDI and microphone inference. Support one active scored input at a time initially; simultaneous MIDI and microphone may be used for controlled evaluation, not double-counted in practice.

### MIDI setup

- Discover devices, select an input, display connection status and detect disconnects.
- Explain that MIDI sends performance information, not the keyboard's speaker sound. Some controllers therefore need a local app synthesizer for audible feedback.
- If the keyboard has Bluetooth audio only, offer microphone or a compatible USB/DIN-to-MIDI route after checking its manual. Do not promise an arbitrary Bluetooth adapter will work.
- Request only necessary permissions. Avoid SysEx in the MVP. Do not collect hardware identifiers for analytics without a reason.
- Test note-on, note-off, velocity, sustain pedal, repeated notes, all-notes-off and range limits. Handle note-on with zero velocity as note-off for supported MIDI 1.0 input. [S19]

### Calibration

Ask the learner to play a few specified notes and a chord. Confirm octave, transpose setting and tuning assumptions. A keyboard transposed electronically can send or sound different pitches depending on configuration; record the tested behavior, not just the label on the keys.

Measure performance-event receipt to visible feedback on the target device. Use monotonic clocks, preserve incoming timestamps when meaningful, and map all sources into one timebase. Do not score timing from a UI animation clock.

### Recovery

On disconnect, pause scoring and clear held-note state. On reconnect, ask to resume at a chosen measure. Do not count a dropped connection as mistakes or replay stale events. Provide a visible “Clear stuck notes” action and debounce connection notifications.

## 8. Microphone listening: two separate products

**Live listening** asks what the learner is playing right now, with a known expected score. **Audio import** asks for a complete transcription of a recording that may have no score. Different latency, context and correction requirements mean they should not share one undifferentiated “AI recognition” feature.

### Single-note prototype

Capture audio locally, normalize the actual device sample rate, and use a pitch estimator with onset detection. A YIN-style or autocorrelation approach is a candidate for monophonic passages. Detect silence, clipping and low confidence. Reject ambiguous frames rather than guessing. A single largest FFT peak is insufficient as the product's piano-note detector: harmonics, multiple notes and room sound make that strategy fragile.

### Polyphonic candidate pipeline

Audio capture → bounded buffer → resampling and features required by the selected model → onset and active-pitch probabilities → temporal smoothing → note events → score alignment. Handle repeated notes, pedal resonance, octave confusions, soft attacks and chords. Model-specific sample rate, hop size and look-ahead must come from the chosen implementation, not generic settings.

Basic Pitch documents polyphonic transcription and says it works best on one instrument at a time; its file-conversion capability does not establish a causal low-latency live path. Onsets and Frames is a solo-piano transcription reference, not a promise of mobile live accuracy. [S6, S10]

Do not run heavy inference on the UI thread or allocate unpredictably on an audio callback. On the web, AudioWorklet supports custom processing off the main thread; heavy inference still needs an appropriate worker/runtime design and measurement. [S14]

Permit microphone MVP release only for tested tasks. Keep unsupported dense two-handed material in unscored or MIDI-only mode until it passes the same evaluation contract.

## 9. Listening calibration, latency and uncertainty

### Setup routine

1. Confirm the selected microphone and output route.
2. Measure room noise, signal level and clipping while idle and while playing.
3. Ask for a reference note, a few separated notes and a chord if that mode is supported.
4. Estimate tuning offset and permitted input range without automatically “correcting” intentional transposition.
5. Offer earphones or mute app accompaniment if the microphone hears its own demonstration.

Request rawer musical capture where the platform permits it, such as disabling speech-oriented noise suppression or automatic gain adjustments. Treat those settings as requests and inspect actual capabilities; do not assume every device honors them.

### Timing budget

Instrument attack → input buffering → feature/model context → inference → event decision → score matching → visual feedback. Measure each component. Offline models may inspect future audio. Chunking them does not automatically remove that look-ahead. Quantization can reduce computation but may change note quality, so benchmark again.

Do not confuse output/headphone delay with MIDI input delay. Bluetooth headphones may make demonstration and rhythm playback feel delayed even when MIDI input is fast; include output route in calibration and support testing rather than promising a fixed delay for all devices.

### Uncertainty policy

Each inferred note includes a confidence estimate and onset uncertainty. If alignment or detection is uncertain, display “Listening unclear,” pause judgment, and offer a retry. Never treat confidence numbers from different models as calibrated probabilities without testing.

Expected-score conditioning can help following, but it must still detect plausible wrong notes. Evaluate false passes deliberately. Otherwise the app may reward what the score expected rather than what the learner actually played.

Exact note release and dynamics are more credible from MIDI than room audio in a pedaled passage. Keep pitch/onset feedback separate from optional duration, articulation and expressive grading.

## 10. Score import and correction pipeline

### Input priority

1. `.musicxml` and compressed `.mxl`: preferred structured notation.
2. Standard `.mid`/`.midi`: performance events, with track/rhythm review.
3. Printed PDF, PNG or JPEG: OMR plus review.
4. Audio: later transcription draft, never automatic approval.

### Structured import

Validate format and size, preserve the original privately, parse into a versioned canonical score, identify supported notation and report unsupported features. Use a small golden-score corpus to test backup/forward timing, multiple voices, cross-staff notes, accidentals, ties, pickup measures, tuplets and meter changes. Avoid treating every voice as consecutive events.

### Image/PDF import

Render pages safely, detect orientation, crop, deskew and remove obvious photographic distortion. Run OMR, export symbolic output, then present original page and interpreted score together. Audiveris offers OMR, editing and MusicXML export, but is AGPL-3.0 and acknowledges imperfect recognition. Decide license obligations before integrating it in a service or distributed product. Process isolation is operationally useful, not a legal exemption. [S7]

### Review requirements

Let the user correct pitch, accidental, duration, rest, hand/staff assignment, ties, tempo and measure boundaries. Play short excerpts for verification. If a full editor is too much for the MVP, support external correction and reimport plus a small internal correction tool. OSMD is a renderer, not a full notation editor. [S9]

Do not fabricate per-note OMR confidence if the engine does not expose it. Use engine uncertainty where available plus structural checks: incomplete measures, impossible durations, missing clefs and suspicious pitch ranges.

### Hard cases

Handwriting, orchestral scores, tablature, extensive ornaments, unusual notation and unresolvable repeat/jump logic should fail with specific guidance. Preserve the scan for reference, but prevent uncertain material from generating misleading grades.

## 11. Canonical music model and rendering

The canonical model is the product's center. Imported files, audio inference and the renderer should not dictate the learning engine's internal structure.

### Separate three representations

- **Notation:** written pitch spelling, staff, voice, clef, beams, measure, tie/slur, printed layout and source provenance.
- **Performance graph:** playable events, beats, repeats, endings, jumps, tempo map, pedal and traversal state.
- **Practice projection:** selected hand, phrase, simplified arrangement, transposition and tolerance policy.

Use exact rational beat positions and durations. Do not accumulate floating-point rounding across tuplets and measures. Store MIDI pitch alongside written spelling; C-sharp and D-flat may sound alike but have different notation meaning. Store score pitch and sounding pitch separately where transposition or octave marks apply.

Expand supported repeats into unique playback occurrences while retaining original measure IDs and occurrence numbers. A tie extends one note across written segments; it does not demand another attack. A slur does not merge notes. Rests are scored absence over time, not an instruction to wait for input.

A written staff is not a guaranteed physical hand. Permit manual overrides for cross-staff music, overlapping ranges and imported MIDI tracks.

### Renderer choice

OSMD is the first renderer to evaluate for a TypeScript-based notation view. Its repository documents MusicXML rendering, cursor interaction, limitations and BSD-3-Clause licensing. Some audio/native-related features are sponsor early access; do not assume they are included in the open renderer. [S9]

Verovio is an alternative to evaluate for notation needs, but its LGPLv3 conditions and embedding approach require review. [S11]

Keep your own event-to-glyph mapping, so highlighting follows stable score IDs after reflow or rotation. Rendering and sound playback are separate systems. Use a licensed piano sound source; note-rendering libraries do not grant sample-library rights.

## 12. Following the score and evaluating performance

### Wait-for-note mode

Group expected simultaneous attacks into an onset group. Accept a chord within a configurable spread window instead of requiring exactly identical timestamps. Offer strict chord and beginner rolled-chord policies. Require fresh attacks for repeated notes; holding one C cannot satisfy four written C attacks. A tied continuation does not require a fresh attack.

Wait mode ignores free-running rhythm for advancement, but still handles rests through a stated policy. Demonstrate and count rests, or use a learner-controlled continuation in untimed practice. Do not freeze forever waiting for a note during a rest.

### Rhythm mode

Use a count-in and a tempo map. Match events one-to-one to expected attacks within calibrated windows. Prevent one played note from satisfying several expected notes. Distinguish early, late, extra and missed notes. Use separate onset and release tolerances; do not penalize held pedal resonance as repeated attacks.

### Free-tempo following

Start with bounded local sequence alignment or a beam-search/HMM-style follower over expected events. Track position candidates, tempo and confidence. Add costs for skipped, extra, repeated and wrong notes. Recover from a stopped learner, a restart or a jump without silently teleporting to any matching chord in the piece.

Use a visible “Start here” measure selection. Limit automatic jumps in scored mode and require confirmation when position confidence collapses. Repeated passages need occurrence-aware alignment.

### Transparent scoring

For reliable input, report matched attacks, missed expected attacks, extra attacks and timing error distribution. Show precision and recall separately if useful; a single percentage can hide extra notes. Label unscored or detector-uncertain spans and exclude them from mastery calculations.

Maintain a replayable event trace with score revision, matcher version and settings. Deterministic replay should reproduce the grade. Pedal-aware sounding duration and key-held duration are distinct. Do not infer fingering, hand posture or muscle tension from MIDI or microphone notes alone.

## 13. Teaching design: turn feedback into progress

### Practice modes

- Listen: play a phrase with a visible cursor, optionally one hand at a time.
- Find the notes: untimed, with keyboard cues and optional note names.
- Build the phrase: two to four measures, slow tempo, repeatable loop.
- Add rhythm: count-in and metronome, with feedback after the phrase rather than constant interruption.
- Hands together: only after the learner opts in; do not assume separate-hand success guarantees coordination.
- Perform: reduced hints, no stopping, summary afterward.
- Recall: revisit a previously learned phrase after a delay, with fewer cues.

### Proposed adaptive policy

Start at a comfortable tempo selected by the learner. After two reliable attempts with few errors and no long stops, offer a small tempo increase, for example 5%. After repeated errors, shorten the loop, slow down, or isolate a hand. These are initial design rules to validate with learners, not proven pedagogical thresholds.

Track mastery per phrase and tempo, with confidence and last-practiced time. A correct one-off run is not permanent mastery. Keep assisted and unassisted success separate.

### Explain the mistake

Translate evidence into a small exercise: a repeated interval, a chord transition, a rhythm pattern or a troublesome hand entry. Suggest one next action instead of a list of ten faults. Let the learner disagree with a grade and mark a recognition issue.

### Boundaries of automated teaching

Do not diagnose physical technique or guarantee progress speed. Provide a comfortable setup reminder and advise stopping if playing hurts. Fingering suggestions must be editable and labeled suggestions unless sourced from a reviewed edition. Good fingering depends on the passage and the player's hand, not only the next pitch.

Validate the learning flow with actual users, ideally including a piano teacher. The test is whether they can play better away from the screen, not whether they can keep the app's notes green.

## 14. Screens, controls and accessibility

### Essential screens

**Library:** search, import, readiness status, recently practiced and source details.

**Connection:** input selection, supported transport explanation, live note display, calibration and troubleshooting.

**Import review:** original/recognized score, warnings, short playback, corrections and approve-for-practice.

**Practice:** readable current system, optional virtual keyboard/falling-note view, large start/pause, hand selector, tempo, loop handles, input health and one feedback line.

**Session summary:** reliable strengths/errors, phrase-level progress, replay and next exercise.

**Settings:** latency/tuning, score display, privacy, export/delete, audio route and supported-device diagnostics.

### Interaction rules

Keep large touch targets and avoid controls that require precise dragging while sitting at a keyboard. Provide measure selection with tap or typed measure number as an alternative to loop dragging. Preserve playback position on rotation or zoom. Do not auto-scroll in a way that hides upcoming notes or induces motion discomfort.

Use labels or shapes in addition to color: correct, wrong, upcoming, uncertain and unscored must be distinguishable without red/green vision. Support font scaling, strong contrast, reduced motion and keyboard navigation. Give nonvisual names to controls and meaningful screen-reader summaries of practice state. Validate actual notation accessibility rather than claiming a screen reader can interpret every score glyph.

Offer both notation and a visual-keyboard learning view, but make them projections of the same event model. Make note labels optional and distinguish written note names from key positions after transposition.

Falling notes are an optional visualization, not the definition of the product. Sheet music, phrase structure, listening and independent recall remain important if the objective is learning songs rather than following prompts indefinitely.

## 15. Architecture and module boundaries

### Local real-time path

Input adapter → timestamp normalizer → performance-event bus → active-note state → alignment/evaluation engine → practice state → visual feedback.

The audio adapter adds capture, model inference and confidence before producing performance events. The playback engine reads the performance graph and uses the audio clock, independently of animation frames. UI rendering subscribes to state snapshots without blocking capture or matching.

### Content preparation path

Private import → validation/quarantine → parser or asynchronous OMR/transcription job → canonical score → review/corrections → approved revision → local practice cache.

### Suggested repository modules

`apps/client`, `packages/music-model`, `packages/score-import`, `packages/follower`, `packages/lesson-engine`, `packages/renderer-adapter`, `packages/input-contracts`, `packages/test-fixtures`, and optional `services/import-worker`.

For native-first development, preserve these conceptual boundaries even if they are Swift/Kotlin modules rather than TypeScript packages. Use a shared serialized schema and golden fixtures before adding multiple language implementations. Do not add a cross-language runtime just to satisfy a diagram.

### Storage and cloud

Use local structured storage for songs, revisions, practice settings and summaries. Add accounts and sync only after the local loop works. An optional backend holds authenticated metadata, private object storage and a job queue for imports. A SQL database is a reasonable candidate, not a dependency for a single-user prototype.

No network call should be needed to decide whether the last played note was correct. A language model may explain a verified error or help structure an exercise; it must not be the note judge, clock, authoritative score parser or permission checker.

Expose adapter interfaces so an OMR engine, model or renderer can be replaced without rewriting learning logic. Record schema versions and migrations from the first saved score.

## 16. Data contracts and API sketch

The following are proposed schemas, not existing APIs. Use explicit units, nullable unknowns and versioned enums.

### Core records

- `Song`: id, title, composer, arranger, sourceType, sourceAssetId, rightsStatus, rightsNotes, supportedModes, activeScoreRevision.
- `ScoreRevision`: id, parentRevisionId, schemaVersion, contentHash, importEngineVersion, reviewState, unsupportedFeatures, createdAt.
- `ScoreNote`: stableId, measureId, staffId, voiceId, writtenPitch, soundingMidiPitch, onsetBeat rational, durationBeat rational, tieGroupId, handOverride, sourceLocation.
- `PlaybackOccurrence`: id, sourceMeasureId, occurrenceIndex, startBeat, endBeat, outgoingTraversal.
- `PerformanceEvent`: id, source, eventType, pitch, velocity nullable, monotonicTimeMs, originalTimestamp nullable, timestampUncertaintyMs, confidence nullable, channel nullable, pedalValue nullable.
- `PracticeSession`: id, scoreRevisionId, passageOccurrenceIds, hand, mode, targetTempo, toleranceVersion, detectorVersion, startedAt, calibrationId.
- `Evaluation`: expectedId, observedIds, classification, onsetErrorMs nullable, confidence, excludedReason nullable.
- `Mastery`: scoreRevisionId, phraseId, hand, tempoBand, assisted, reliableAttempts, recentResult, lastPracticedAt.

### Optional server API

`POST /imports` creates an authenticated import and returns a short-lived upload route; `POST /imports/{id}/process` starts an idempotent job; `GET /imports/{id}` returns state/warnings; `PUT /scores/{id}/revisions` saves reviewed changes with revision preconditions; `POST /sessions` stores optional summaries; `DELETE /songs/{id}` requests asset and derived-data removal.

Jobs have `queued`, `processing`, `needs_review`, `ready`, `failed`, or `canceled` states. Store progress stages, retryable error codes and processor versions. Do not start duplicate paid/cloud work on a repeated tap.

Revision changes must invalidate or explicitly migrate affected phrase references and mastery. Never compare today's edited score with yesterday's incompatible grades without saying so.

## 17. Security, privacy and rights

### Private by design

Prefer on-device note detection. Do not retain raw microphone audio by default. Show when listening is active, release the microphone when practice ends, and separate permission to listen from consent to save or upload recordings. If diagnostic recording is enabled, use explicit opt-in, a stated retention period and deletion controls.

Uploaded scores remain private unless separately shared. Encrypt transport and stored server assets, enforce per-owner access on every route, use short-lived asset URLs, and avoid logging private scores or audio. Test unauthorized access, not just the happy path. Minimize analytics to errors and timing aggregates where possible.

Treat uploaded XML, PDF, archives, filenames, metadata and song text as untrusted input. Disable external XML entities, bound decompression and page counts, isolate converters, enforce timeouts and memory limits, and never execute score-provided scripts or follow embedded instructions. Do not send full uploads to an outside AI service silently.

### Music rights

Composition and recording are distinct copyrighted works. The U.S. Copyright Office explains that different owners and permissions may apply. Public-domain music, permitted use and licensing must be evaluated for the exact edition, recording, territory and intended activity. Owning a score or paying for streaming does not itself establish permission to redistribute it inside an app. [S15]

For a public catalog, commission or license arrangements, demos, sound assets and display/use rights. Obtain qualified review for commercial use, uploads, takedowns and any child-directed product. This plan does not establish legal clearance.

Do not build song import around downloading or transcribing Spotify streams. Its developer policy restricts analysis and ingestion of Spotify content into AI/ML models, and contains synchronization restrictions. A catalog metadata lookup would not grant those rights. [S16]

Keep code, model weights, training data, sample audio and repertoire licenses in separate ledger entries. “Open source” is not permission for every commercial use.

## 18. Dependencies: buy, build or evaluate

### Build the product-specific layer

Own the canonical music model, correction/review states, input normalization, alignment policy, teaching rules, honest confidence handling and mastery logic. These define the experience and need deterministic tests.

### Reuse commodity capability where it fits

- **OS MIDI APIs:** use the platform interfaces, not a custom BLE protocol when standard support is available. [S1-S3]
- **OSMD:** evaluate for rendering/cursor integration; BSD-3-Clause repository license. Check the exact release and separate sponsor components before shipping. [S9]
- **Audiveris:** OMR candidate; AGPL-3.0 requires deliberate legal/architectural review. A commercial OMR service may be another route, but no provider pricing, SLA or rights has been assumed. [S7]
- **Basic Pitch:** Apache-2.0 repository and multiple runtime formats; benchmark for authorized file transcription and possibly adapted live inference. This is not a validated live piano scorer. Inspect exact model artifacts and dependencies. [S6]
- **Onsets and Frames:** research reference for piano-specific onset/frame modeling. Audit the particular code/checkpoint before adoption. [S10]
- **Verovio:** alternate renderer with LGPLv3 conditions. [S11]
- **Piano samples/soundfont:** select only after checking redistribution rights, size, quality and target-device load.

### Dataset caution

MAESTRO provides aligned piano audio/MIDI research data, but the publisher describes a Creative Commons Attribution Non-Commercial Share-Alike license. Do not assume it is an unrestricted commercial training/evaluation source. The original announcement and current dataset page describe different dataset sizes because they cover different versions. Pin the exact version and verify its license. [S17, S18]

Before choosing any package: record exact version/commit, license, maintenance, known security issues, minimum OS/runtime, binary size, offline behavior and a replacement path. Do not prescribe “latest” versions in the implementation handoff without rechecking them at build time.

## 19. Validation plan and proposed quality gates

All numbers below are **initial acceptance targets to validate**, not measured performance or industry guarantees. Tune them with real-device results and learner feedback. Report results by device, input mode and difficulty, not one flattering average.

### Core/MIDI targets

- Golden import fixtures: every supported note, onset, duration, tie and traversal matches the approved expected representation exactly.
- Deterministic replay: identical event trace and settings produce identical grades.
- Event handling: no lost or duplicated events in scripted tests of the declared supported input rates; test repeated attacks, note-offs, pedal and disconnects.
- Local MIDI receipt-to-visible-feedback target: p95 below 50 ms on selected supported devices. Separately measure physical-key-to-app latency using paired capture or a suitable hardware test; timestamps alone cannot prove it.
- Practice recovery: disconnect pauses grading immediately on detection and never adds a run of missed-note penalties.

### Microphone targets

Start with quiet-room, single-note, limited-range lessons: target onset/pitch precision ≥95% and recall ≥90%, using an explicit matching rule such as pitch equality plus onset within ±100 ms. Report unscored/abstained time, false passes, false penalties and onset latency separately. A slow detector must not claim success by evaluating only after the phrase.

Polyphonic release needs a separate chord/voice/range/sustain test set and usable latency. Set its threshold after the spike; do not reuse a monophonic aggregate. If it fails, ship MIDI plus restricted microphone support rather than loosening the grade invisibly.

### Import and teaching targets

OMR is accepted only after review resolves warnings and sampled playback agrees with the source. Track correction effort per page, not just job completion. Run usability sessions with beginners on unseen short passages; compare pre/post unassisted playing, time to start practice, recognition complaints and next-day recall.

No test in this document has been run. Passing one machine or one demo song is not release readiness.

## 20. Test corpus, edge cases and observability

Build small, rights-cleared fixtures with expected outcomes before adding a large song catalog. Hold out pieces and performers from model selection, and separate clean synthetic audio from real room recordings. Synthetic success alone does not validate microphones.

### Required musical cases

Single notes across the supported range; two-, three- and four-note chords; repeated same-pitch notes; rolled chords; tied notes versus repeated attacks; rests; pickups; dotted rhythm; triplets; multiple voices; clef changes; accidentals; overlapping hands; key/meter/tempo changes; octave markings; sustain; repeats and alternate endings. Unsupported ornaments or jumps must produce warnings, not corrupted practice.

### Required environment cases

Quiet/loud playing, room noise, reverberation, phone at different distances, accompaniment leakage, clipping, missing bass/treble content, Bluetooth audio routing, backgrounding, screen lock, low battery, thermal stress, sample-rate change, permission denial, USB unplug, BLE dropout and device sleep.

### Required scoring failures

Play only the correct melody over wrong bass; add many extra notes; hold a note across repeated attacks; deliberately play a nearby octave; skip a measure; restart in a repeat; stop mid-chord; play correct notes with wrong timing. Verify the app neither falsely passes nor loses its place without explanation.

### Instrumentation

Log local event counts, queue depth, audio overruns, dropped buffers, inference duration, alignment confidence and UI update delay. Store bounded diagnostic traces with version information and consent rules. Expose a developer replay mode so grading bugs can be reproduced without asking the learner to repeat a performance.

Track import failures by type, correction effort, starts/completions, confidence-related abstentions and false-grade reports. Do not optimize session length at the expense of learning. Maintain a supported-device matrix with date tested and known restrictions.

## 21. Roadmap, effort and stop/go decisions

These are planning ranges for one experienced engineer with part-time music/QA input, not quotes. They exclude catalog negotiations, unfamiliar-framework learning and broad commercial compliance. Parallel help can shorten calendar time, but hardware/audio integration remains a dependency.

### Phase 0: feasibility and scope | 1-2 weeks

Confirm device/keyboard, test physical MIDI and BLE, import three rights-cleared scores, render/highlight notes, and capture a small microphone test. Deliver a measured compatibility report and a stack decision. Stop or change platform if the actual hardware path fails.

### Phase 1: MIDI vertical slice | 3-5 additional weeks

One input, local library, MusicXML subset, playback, phrase loop, hand selection, wait mode, basic rhythm matching and replay tests. Deliver an end-to-end practice flow on a physical instrument. Keep USB as a diagnostic/reference path even if BLE is the desired experience.

### Phase 2: usable personal tutor | 3-5 additional weeks

Improve import diagnostics, difficult-score handling, progress, recovery, accessibility and real-user testing. Deliver a useful personal version with clear limits. Rough total for this MIDI-first personal product: 7-12 weeks including Phase 0, with scope and skill strongly affecting it.

### Phase 3: reviewed sheet import | 3-6 additional weeks

Select compliant OMR integration, build background jobs and review/correction UX, validate poor scans and failure handling. Complexity depends heavily on how much editing happens inside the app.

### Phase 4: microphone track | 2-4 week spike, then re-estimate

Prove monophonic performance first. Benchmark polyphonic candidates on the target hardware and acoustics. If unsuitable, limit microphone modes rather than promising a completion date. Production-quality polyphonic listening can be a multi-month effort and is not covered by the MIDI timeline.

### Phase 5: commercial expansion | separately scoped

Rights-cleared catalog, account/sync, platform distribution, privacy/legal review, load testing, support and additional devices. Do not quote this as “the same app plus payments.”

## 22. Budget, risk register and launch decision

### Budget model

No vendor spend is approved by this plan. Estimate engineering effort before buying services. Use: **person-weeks × actual weekly cost + hardware + infrastructure + content/licensing + specialist review + contingency**. Personal time is still a real cost even if no contractor invoice exists.

For cloud imports, track pages × OMR compute cost and audio minutes × transcription compute cost, plus storage, egress and job retries. For practice, on-device inference avoids a per-note server cost but increases device optimization work. Get current vendor quotes only after the architecture and volume assumptions are settled. Use a contingency line, for example 25-40% of an early estimate, as a planning choice rather than a market benchmark.

### Main risks and responses

- **Wrong hardware assumption:** verify keyboard manual and real pairing before selecting framework.
- **False recognition feedback:** confidence-aware abstention, MIDI reference traces, mode restrictions and honest beta labels.
- **Bad imported score:** mandatory review state, source comparison and correction/reimport.
- **Loss of musical meaning:** canonical score model, rational timing and golden fixtures.
- **Over-broad song promise:** arrangement-aware search and explicit unavailable/import paths.
- **Licensing surprise:** separate code/model/data/content audit before integration or publication.
- **AI-built demo mistaken for a product:** real hardware tests, deterministic replay and measured release gates.
- **Runaway scope:** one device, one learning loop, a few scores and no accounts first.

### Release checklist

A usable version requires a tested device/input matrix, approved score subset, visible mode limits, passing regression tests, permission/denial recovery, no scoring while disconnected or uncertain, private import storage, reproducible grading, deletion/export behavior and source/license records. A public release adds distribution and commercial-policy review, support, incident handling and rights-cleared content.

The best first milestone is not “supports any song.” It is “I learned a real passage on my own keyboard, the app judged it fairly, and I can reproduce that result tomorrow.”

## 23. Implementation backlog and definition of done

### P0: trustworthy vertical slice

**P0-1 Hardware spike:** discover/select the actual keyboard, receive timestamped notes and pedal, recover from disconnect. Done when physical-device tests and a compatibility note exist.

**P0-2 Music model:** parse the supported MusicXML subset, preserve originals and revisions, expand supported repeats. Done when golden fixtures match exactly and unsupported features are reported.

**P0-3 Renderer/playback:** readable score, event-linked cursor, local piano demo, count-in and tempo map. Done when visual positions and audible events agree after resize and tempo changes.

**P0-4 Evaluator:** wait-for-note and fixed-tempo modes, chord handling, extra/missed-note reporting, deterministic replay. Done when deliberate wrong performances fail for the right reason.

**P0-5 Practice flow:** passage selection, loop, hand choice, pause/resume and summary. Done when an unfamiliar learner can start and complete a four-measure lesson without developer assistance.

### P1: dependable personal use

MIDI-file review; progress persistence; calibration; reconnect handling; accessibility; import warnings; export/delete; error reporting; phrase-level next exercises. Done when a second session reliably resumes and previously fixed bugs stay fixed.

### P2: expansion behind gates

OMR import/review, microphone melody beta, polyphonic spike, broader catalog, optional sync. Each requires its own rights review, quality metrics and fallback path. Do not let a P2 dependency delay a working P0 MIDI learner.

### Shared engineering rules

Add tests with every scoring change. Keep sample scores rights-cleared. Pin dependencies and save lockfiles. Require migration tests for schema changes. Do not accept placeholder recognition, random confidence values, simulated hardware or a green UI as evidence of completion. Simulators help screen work; instrument and audio acceptance happens on real devices.

## 24. Copy-ready refinement prompt

Use the following as an instruction to the app you choose, with this plan attached. Replace bracketed answers if known; otherwise keep them marked unknown.

> I want to refine and eventually build a personal piano-learning app. It must teach selected songs or imported sheet music, accept keyboard performance over Bluetooth MIDI where compatible, and eventually offer microphone note detection. My keyboard is [unknown]. My target device/OS is [unknown]. My coding experience, budget and commercial intent are [unknown]. Do not invent these answers.
>
> Treat the attached plan as a proposal, not as proof of tested software. Preserve the complete ambition, but start with a MIDI-first vertical slice on my actual hardware and a reviewed MusicXML score. Distinguish Bluetooth MIDI from audio; score import from sound detection; and live feedback from offline transcription. Do not claim any-song catalog access or perfect PDF/audio conversion.
>
> First ask only the decisions that change architecture. Then provide: a selected platform with reasons and rejected alternatives; an explicit MVP and supported notation subset; module boundaries; versioned data schemas; screen flows; a dependency/license review checklist; deterministic evaluation rules; test fixtures; measurable hardware/audio quality gates; a scoped backlog; and a revised effort/budget estimate with uncertainty.
>
> Check current platform APIs and package licenses before selecting exact versions. Do not add a backend, login, chat tutor, paid service, catalog scrape or model training unless it solves a specific accepted requirement. Do not use Spotify or other streaming access as permission to download, transcribe or redistribute music.
>
> If you can generate code, propose the first narrow milestone before coding. Keep note evaluation deterministic and separate from AI-written explanations. Use real-device tests, not simulated success. Maintain TODOs for unverified assumptions. If a target cannot be met, explain the tradeoff and offer a safe reduced mode rather than silently changing the requirement.

### First implementation prompt, only after decisions

> Build only the P0 vertical slice: connect the verified MIDI input, import one rights-cleared structured score, show and play it, teach a selected passage in wait and rhythm modes, and replay captured events through deterministic tests. No microphone ML, OMR, accounts or catalog scraping in this slice. Return setup instructions, supported devices/formats, tests, known limitations, and the next decision. Do not claim hardware validation you have not performed.

## 25. Source notes and evidence boundaries

Sources were checked November 13, 2026. They establish platform/tool capabilities, documented limitations and policy constraints. They do not establish performance for this proposed app. Architecture, learning rules, estimates and thresholds above are recommendations, not source-reported benchmarks.

### MIDI and platforms

**S1. Apple, MIDI Bluetooth.** Current official documentation entry point for Bluetooth MIDI. The detailed archived guide below supplies the connection behavior used in this plan.
https://developer.apple.com/documentation/coremidi/midi-bluetooth

**S2. Apple, Adding Bluetooth LE MIDI Support.** Official archived technical guide: native BLE MIDI, CoreAudioKit connection controllers and ordinary MIDI endpoints after connection. Historical API introduction dates are not current deployment recommendations.
https://developer.apple.com/library/archive/qa/qa1831/_index.html

**S3. Android Open Source Project, MIDI.** Official platform documentation, page updated October 9, 2026: USB/BLE/virtual transport support and optional MIDI capability.
https://source.android.com/docs/core/audio/midi

**S4. MDN, Web MIDI API.** Independent technical reference: access, permissions, secure context, inputs/outputs and connection events.
https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API

**S5. Can I use, Web MIDI.** Independent compatibility evidence: Safari lacks native Web MIDI; other browsers have differing support. Recheck at implementation; extensions do not equal native browser support.
https://caniuse.com/midi

### Recognition, notation and rendering

**S6. Spotify, Basic Pitch repository.** Project documentation: polyphonic audio-to-MIDI, best with one instrument at a time, runtime formats, and Apache-2.0 repository license. Vendor/project claims are not live-use measurements.
https://github.com/spotify/basic-pitch/

**S7. Audiveris repository.** Project documentation: OMR plus correction editor, imperfect recognition, MusicXML export and AGPL-3.0 license. No claim of perfect scans or a legally exempt deployment architecture.
https://github.com/Audiveris/audiveris

**S8. W3C Music Notation Community Group, MusicXML 4.0.** June 1, 2021 final community report for digital sheet-music exchange; explicitly not a W3C Standard.
https://www.w3.org/2021/06/musicxml40/

**S9. OpenSheetMusicDisplay repository and license.** Project documentation: MusicXML rendering/cursor, incomplete format coverage, not a full editor, separate early-access features; BSD-3-Clause license.
https://github.com/opensheetmusicdisplay/opensheetmusicdisplay
https://github.com/opensheetmusicdisplay/opensheetmusicdisplay/blob/develop/LICENSE

**S10. Magenta, Onsets and Frames.** Primary research-project explanation, February 12, 2018: polyphonic solo-piano transcription and onset/frame architecture. Historical research, not a current product benchmark.
https://magenta.withgoogle.com/onsets-frames

**S11. Verovio licensing.** Project's own explanation of LGPLv3 obligations and distribution considerations. Exact integration still needs review.
https://book.verovio.org/introduction/licensing.html

### Browser audio, rights and data

**S12. MDN, getUserMedia.** Microphone access requires permission and a secure context; denial and device errors must be handled.
https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia

**S13. MDN, Web MIDI API.** Same source as S4, also supporting secure-context and MIDI permission requirements.
https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API

**S14. MDN, AudioWorklet.** Custom audio processing in a separate thread for low-latency processing; not a guarantee of total app latency.
https://developer.mozilla.org/en-US/docs/Web/API/AudioWorklet

**S15. U.S. Copyright Office, What Musicians Should Know about Copyright.** Separate musical-work/recording rights and permission principles. U.S.-focused source, not individualized legal advice.
https://copyright.gov/engage/musicians/

**S16. Spotify Developer Policy.** Current restrictions on content analysis, AI/ML ingestion and synchronization. Terms can change; recheck before any integration.
https://developer.spotify.com/policy

**S17. Magenta, MAESTRO dataset.** Primary dataset page: aligned audio/MIDI, versioned releases and current corpus description.
https://magenta.withgoogle.com/datasets/maestro

**S18. Magenta, MAESTRO and Wave2Midi2Wave.** October 30, 2018 original research announcement explicitly describing a non-commercial/share-alike license. Its original corpus size differs from later versions; this plan does not assume unrestricted commercial data rights.
https://magenta.withgoogle.com/maestro-wave2midi2wave

**S19. MIDI Association community forum, Zero velocity note on.** Community discussion quoting the MIDI 1 convention that note-on at zero velocity terminates a note. Confirm event handling against the selected platform parser and device fixtures.
https://midi.org/community/midi-specifications/zero-velocity-note-on

### What remains unverified

No keyboard compatibility, package build, model benchmark, acoustic evaluation, OMR accuracy test, learner study, legal clearance or vendor price was verified for your particular project. These are explicit Phase 0 and release-gate tasks, not hidden work already completed. The next useful action is choosing the actual device/keyboard pair and proving the smallest learning loop.
