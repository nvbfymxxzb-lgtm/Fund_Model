#!/usr/bin/env python3
"""Writes skills.json and the lesson files. Edit lessons here, then run this script.

All lessons are drafts: written for this app, not reviewed by a piano teacher.
Every example and answer is checked by the app's own tests (ContentTests), which
validate chords, scales and answers against the theory code.
"""
import json, os

ROOT = os.path.join(os.path.dirname(__file__), "..", "PianoCore", "Sources", "Curriculum", "Content")

SKILLS = [
    ("p.posture", "pianoTechnique", "Sitting and hand shape", []),
    ("p.keyboard", "pianoTechnique", "Finding notes on the keyboard", []),
    ("p.scales", "pianoTechnique", "Scales and fingering", ["p.posture"]),
    ("p.blockChords", "pianoTechnique", "Playing chords", ["m.triads"]),
    ("p.inversions", "pianoTechnique", "Chord inversions and smooth changes", ["p.blockChords"]),
    ("p.brokenChords", "pianoTechnique", "Broken chords", ["p.blockChords"]),
    ("p.legato", "pianoTechnique", "Legato touch", ["p.scales"]),
    ("p.dynamics", "pianoTechnique", "Loud, soft and balance between the hands", []),
    ("p.pedal", "pianoTechnique", "Pedaling", ["p.legato"]),
    ("p.handIndependence", "pianoTechnique", "Independent hands", ["p.scales"]),
    ("p.practice", "pianoTechnique", "How to practise", []),
    ("m.rhythm", "musicTheory", "Note values and meter", []),
    ("m.compoundMeter", "musicTheory", "Six-eight and other compound meters", ["m.rhythm"]),
    ("m.intervals", "musicTheory", "Intervals", []),
    ("m.majorKeys", "musicTheory", "Major scales and key signatures", ["m.intervals"]),
    ("m.minorKeys", "musicTheory", "Minor keys", ["m.majorKeys"]),
    ("m.triads", "musicTheory", "Triads", ["m.intervals"]),
    ("m.seventhChords", "musicTheory", "Seventh chords", ["m.triads"]),
    ("m.roman", "musicTheory", "Chords in a key (Roman numerals)", ["m.triads", "m.majorKeys"]),
    ("m.cadences", "musicTheory", "Cadences and common progressions", ["m.roman"]),
]

def text(t): return {"type": "text", "text": " ".join(t.split())}
def keyboard(keys, labels=None, caption=None):
    b = {"type": "keyboard", "keys": keys}
    if labels: b["labels"] = labels
    if caption: b["text"] = caption
    return b
def scale(tonic, kind="major", hand="right", caption=None):
    b = {"type": "scale", "scaleTonic": tonic, "scaleType": kind, "hand": hand}
    if caption: b["text"] = caption
    return b
def chord(root, quality="major", inversion=0): return {"root": root, "quality": quality, "inversion": inversion}
def chords(specs, labels=None, caption=None):
    b = {"type": "chords", "chords": specs}
    if labels: b["chordLabels"] = labels
    if caption: b["text"] = caption
    return b
def checklist(items, caption=None):
    b = {"type": "checklist", "items": items}
    if caption: b["text"] = caption
    return b
def song(id, caption): return {"type": "songLink", "songId": id, "text": caption}
def gen(kind, count, caption=None, **kw):
    b = {"type": "generated", "generator": dict(kind=kind, count=count, **kw)}
    if caption: b["text"] = caption
    return b
_n = [0]
def ex(kind, prompt, **kw):
    _n[0] += 1
    return {"type": "exercise", "exercise": dict(id=f"ex{_n[0]}", kind=kind, prompt=prompt, **kw)}
def choice(prompt, options, answer, explanation):
    return ex("choice", prompt, options=options, answer=answer, explanation=explanation)
def play_chord(prompt, spec, inversion=False, explanation=None):
    kw = dict(chord=spec, requireInversion=inversion)
    if explanation: kw["explanation"] = explanation
    return ex("playChord", prompt, **kw)
def play_scale(prompt, tonic, kind="major", hand="right"):
    return ex("playScale", prompt, scaleTonic=tonic, scaleType=kind, hand=hand, octaves=1)
def progression(prompt, specs, labels, explanation=None):
    kw = dict(chords=specs, labels=labels)
    if explanation: kw["explanation"] = explanation
    return ex("playProgression", prompt, **kw)

HEARS = "The app listens to which keys you press, how hard and when. It cannot see your hands, so the points in this lesson are for you to check yourself."

def lesson(id, title, summary, minutes, skills, blocks, sources=None):
    d = dict(id=id, title=title, summary=summary, minutes=minutes, skillIds=skills, reviewState="draft", blocks=blocks)
    if sources: d["sources"] = sources
    return d

UNITS = []
def unit(id, track, order, title, summary, lessons):
    UNITS.append(dict(id=id, track=track, order=order, title=title, summary=summary, lessons=lessons))

# ---------------------------------------------------------------- Piano technique & theory

unit("P1", "pianoTechnique", 1, "Setting up", "How to sit, how to hold your hands, and how to find your way around the keys.", [
    lesson("p1.1", "Sitting and hand shape", "A comfortable position you can keep without strain.", 6, ["p.posture"], [
        text("Good technique starts before you play a note. The aim is simple: nothing should feel tight or held. If something hurts while you play, stop and rest."),
        text(HEARS),
        checklist([
            "Sit on the front half of the bench, feet flat on the floor.",
            "Sit far enough back that your elbows are slightly in front of your body, not pinned to your sides.",
            "Adjust the bench height so your forearms are about level with the keys.",
            "Let your shoulders drop. Check them again after a minute of playing.",
            "Let your fingers curve naturally, as if holding a small ball. The thumb rests on its side corner.",
            "Keep the wrist level with the hand: not sagging below the keys and not arched high.",
        ], "Check each point at your piano:"),
        text("Play from the weight of your arm rather than by pressing hard with the fingers alone. A relaxed arm gives a fuller sound for less effort."),
        choice("Something starts to ache in your forearm during practice. What should you do?",
               ["Push through; it will loosen up", "Stop, rest, and check your position before continuing", "Play louder to build strength", "Lower the bench as far as it goes"], 1,
               "Pain is a signal to stop. Rest, then check your seat height, shoulders and wrists. If it keeps happening, ask a teacher or a doctor."),
        text("The app cannot check any of this for you. Recording a short video of yourself from the side, or a single lesson with a teacher, is the best way to check your position."),
    ]),
    lesson("p1.2", "Finding your way around the keys", "Use the black keys as landmarks.", 6, ["p.keyboard"], [
        text("The black keys come in groups of two and three. Every C sits just left of a group of two black keys, and every F sits just left of a group of three."),
        keyboard([60, 65], ["C", "F"], "Middle C, and the F above it."),
        text("From one key to the very next key, black or white, is a half step. Two half steps make a whole step."),
        keyboard([60, 61, 62], ["C", "C♯", "D"], "C to C♯ is a half step. C to D is a whole step."),
        choice("Which white key sits just left of a group of three black keys?", ["C", "E", "F", "B"], 2, "F is left of the three black keys; C is left of the two."),
        choice("How many half steps are there from E up to F?", ["One", "Two", "Three", "None"], 0, "E and F are next-door white keys with no black key between them: one half step."),
        ex("playInterval", "Play the note a whole step above D4 (the D next to middle C).", rootMidi=62, semitones=2,
           explanation="A whole step above D is E."),
        ex("playInterval", "Play the note a half step above E4.", rootMidi=64, semitones=1, explanation="A half step above E is F."),
    ]),
])

unit("P2", "pianoTechnique", 2, "Scales and fingering", "Even scales with the standard fingerings, starting with the thumb crossing.", [
    lesson("p2.1", "C major and the thumb crossing", "Eight notes with five fingers: where the thumb passes under.", 10, ["p.scales"], [
        text("A scale has eight notes but you have five fingers, so the hand has to shift. Going up in the right hand, the thumb passes under after finger 3. The fingering is 1 2 3, then 1 2 3 4 5."),
        scale("C", "major", "right", "C major, right hand, with fingering."),
        text("Keep the hand level as the thumb passes under. Move the thumb early, while finger 2 and 3 are playing, so it is already waiting over its key. Do not twist the wrist or lift the elbow to make room."),
        text("Coming down, finger 3 crosses over the thumb. The left hand mirrors this: going up it plays 5 4 3 2 1, then finger 3 crosses over, 3 2 1."),
        play_scale("Play C major, right hand, up and down. Go slowly; the music waits for you.", "C", "major", "right"),
        scale("C", "major", "left", "C major, left hand."),
        play_scale("Now the left hand.", "C", "major", "left"),
        text("After each scale the app shows how even your notes were in timing and in loudness. A common pattern is a bump at the crossing: the note after the thumb comes late or loud. If you see that, practise just the three notes around the crossing."),
        play_scale("Play C major hands together.", "C", "major", "both"),
    ], sources=["Standard scale fingering as printed in common scale manuals; check against your own reference."]),
    lesson("p2.2", "G, D and F major", "The same shape with one or two black keys, and one new fingering.", 10, ["p.scales", "m.majorKeys"], [
        text("G major and D major use exactly the same fingering as C major. G major has one sharp, F♯. D major has two, F♯ and C♯."),
        scale("G", "major", "right"),
        play_scale("Play G major, right hand.", "G", "major", "right"),
        play_scale("Play G major, left hand.", "G", "major", "left"),
        scale("D", "major", "right"),
        play_scale("Play D major, right hand.", "D", "major", "right"),
        text("F major has one flat, B♭. In the right hand the thumb cannot land on the black key, so the fingering changes: 1 2 3 4, then 1 2 3 4. The left hand keeps the usual fingering."),
        scale("F", "major", "right"),
        play_scale("Play F major, right hand. The thumb passes under after finger 4.", "F", "major", "right"),
        play_scale("Play F major, left hand.", "F", "major", "left"),
    ], sources=["Standard scale fingering as printed in common scale manuals; check against your own reference."]),
    lesson("p2.3", "A minor", "The minor scale that shares C major's notes, and its harmonic form.", 8, ["p.scales", "m.minorKeys"], [
        text("A natural minor uses only white keys, like C major, but starts and ends on A. The fingering is the same as C major."),
        scale("A", "naturalMinor", "right"),
        play_scale("Play A natural minor, right hand.", "A", "naturalMinor", "right"),
        text("Music in a minor key very often raises the seventh note by a half step, which pulls strongly back to the keynote. In A minor that note is G♯. This form is called the harmonic minor."),
        scale("A", "harmonicMinor", "right"),
        play_scale("Play A harmonic minor, right hand. Listen for the wide step from F to G♯.", "A", "harmonicMinor", "right"),
        song("greensleeves", "Greensleeves is in A minor and uses both G and G♯."),
    ]),
])

C_, F_, G_ = chord("C"), chord("F"), chord("G")
unit("P3", "pianoTechnique", 3, "Chords on the keyboard", "Triad shapes, inversions, and moving between chords with the least motion.", [
    lesson("p3.1", "Triad shapes", "Major and minor triads under the hand.", 8, ["p.blockChords", "m.triads"], [
        text("A triad is a three-note chord built by skipping every other note of the scale: play one, skip one, play one, skip one, play one. With the notes this close together it sits under fingers 1, 3 and 5 of the right hand, or 5, 3 and 1 of the left."),
        chords([chord("C"), chord("C", "minor")], ["C major", "C minor"], "The middle note decides major or minor."),
        text("Press all three keys at exactly the same moment, with a relaxed drop of the arm. Then release and let the hand stay loose."),
        play_chord("Play a C major chord.", chord("C")),
        play_chord("Play an A minor chord.", chord("A", "minor")),
        gen("chordPlay", 6, "Now play each chord the app asks for. Any octave is fine.", keys=["C", "F", "G", "D", "A", "E"], qualities=["major", "minor"]),
    ]),
    lesson("p3.2", "Inversions", "The same three notes with a different one at the bottom.", 10, ["p.inversions", "m.triads"], [
        text("You can play the notes of a chord in any order. When the root is at the bottom the chord is in root position. Move the bottom note up an octave and you get the first inversion; do it again for the second inversion."),
        chords([chord("C", "major", 0), chord("C", "major", 1), chord("C", "major", 2)], ["root position", "first inversion", "second inversion"]),
        text("Usual right-hand fingerings are 1 3 5 for root position, 1 2 5 for first inversion and 1 3 5 for second inversion. Let your hand choose what is comfortable; the app does not know which fingers you use."),
        play_chord("Play C major in first inversion: E at the bottom.", chord("C", "major", 1), True),
        play_chord("Play C major in second inversion: G at the bottom.", chord("C", "major", 2), True),
        play_chord("Play F major in second inversion: C at the bottom.", chord("F", "major", 2), True),
        gen("chordPlay", 6, "Play each chord with the named note at the bottom.", keys=["C", "F", "G"], qualities=["major"], inversions=True),
    ]),
    lesson("p3.3", "Changing chords smoothly", "Use inversions so the hand hardly moves.", 10, ["p.inversions", "m.roman"], [
        text("If you play C, F and G all in root position, the hand has to jump. Use inversions instead and the chords sit right next to each other: notes that two chords share stay where they are, and the other fingers move by a step."),
        chords([chord("C"), chord("F", "major", 2), chord("G", "major", 1), chord("C")], ["C", "F (C at the bottom)", "G (B at the bottom)", "C"],
               "From C to F the bottom note C stays. From C to G the top note G stays."),
        progression("Play C, then F with C at the bottom, then G with B at the bottom, then C again.",
                    [chord("C"), chord("F", "major", 2), chord("G", "major", 1), chord("C")], ["C", "F/C", "G/B", "C"],
                    "These are the three main chords of C major, played without moving the hand away."),
        text("Before each change, look for the note the two chords share and keep that finger down."),
        song("when-the-saints", "When the Saints uses exactly these three shapes in the left hand."),
        song("ode-to-joy", "Ode to Joy moves between C and G with B at the bottom."),
    ]),
])

unit("P4", "pianoTechnique", 4, "Touch, balance and pedal", "Joining notes, keeping the melody on top, and using the right pedal cleanly.", [
    lesson("p4.1", "Legato: joining the notes", "Release each key as the next one goes down.", 8, ["p.legato"], [
        text("Legato means smoothly connected. On the piano you get it by releasing each key at the moment the next key goes down, so the sounds join with no gap and no blur."),
        text("The app measures this directly: for each pair of notes it compares when you released the first with when you pressed the second. A small overlap is legato. A gap means the notes were detached. A long overlap means two notes were sounding at once."),
        play_scale("Play C major, right hand, as smoothly as you can. Then read the legato figure in the result.", "C", "major", "right"),
        text("If the result shows gaps, try this: hold each note until you feel the next key reach the bottom, and only then let go. If it shows long overlaps, lift each finger a little sooner."),
        song("amazing-grace", "Amazing Grace is a good piece for a singing, joined-up melody."),
    ]),
    lesson("p4.2", "Melody over accompaniment", "Make one hand louder than the other on purpose.", 8, ["p.dynamics"], [
        text("In most pieces one hand carries the tune and the other supports it. The tune should be clearly louder. This is hard at first because the hands want to do the same thing."),
        text("Practise it away from a piece. Play the same five notes in both hands, and let the right hand sink into the keys with more arm weight while the left hand stays close to the keys and plays lightly."),
        text("After you play a piece with both hands, the app shows the balance: the average loudness of the right hand minus the left. For a right-hand tune this should be clearly positive. The number depends on your piano's Key Touch setting, so compare it only with your own earlier results."),
        choice("You play a piece where the right hand has the tune. The app reports a balance of −12. What does that mean?",
               ["The right hand was louder, as it should be", "The left hand was louder than the tune", "You played 12 wrong notes", "The tempo was 12% slow"], 1,
               "Balance is right-hand loudness minus left-hand loudness. A negative number means the left hand was louder than the tune, so lighten the left hand."),
        song("auld-lang-syne", "In Auld Lang Syne the left-hand broken chords should stay well under the tune."),
        song("brahms-lullaby", "In the Lullaby the two soft chords in each measure must be quieter than the melody."),
    ]),
    lesson("p4.3", "The right pedal", "Change the pedal just after the new chord, not before.", 8, ["p.pedal"], [
        text("The right pedal lifts the dampers so notes keep sounding after you release the keys. It joins chords that the hands cannot join, but if you hold it through a change of chord the two harmonies blur together."),
        text("The clean way is called legato pedaling. Play the new chord, and at that moment, or a split second after, lift the pedal and press it straight down again. The foot goes up as the hands go down."),
        text("The common mistake is to lift and press the pedal before the new chord, which leaves a gap in the sound, or not to lift it at all. The app can time your pedal against the chord changes when your pedal is connected."),
        choice("When should the pedal come up in legato pedaling?",
               ["Just before the new chord, to clear the old one", "As the new chord sounds, or just after", "Half-way through the measure", "Never; hold it down"], 1,
               "Lift as the new chord sounds and press again straight away. That clears the old harmony while the new one is held by your fingers."),
        song("gymnopedie-1", "Gymnopédie No. 1 needs one pedal change on each bass note."),
    ]),
    lesson("p4.4", "How to practise", "Short loops, slow tempo, and stopping while it is still going well.", 6, ["p.practice"], [
        text("Most progress comes from playing a small passage correctly several times, not from playing a whole piece through with the same mistakes."),
        checklist([
            "Work on two to four measures at a time.",
            "Learn each hand alone before putting them together.",
            "Choose a tempo slow enough to play with no mistakes, then raise it in small steps.",
            "When a spot keeps going wrong, shrink the loop to the two or three notes around it.",
            "Stop after a good run. End a session on something that worked.",
            "Come back the next day: what you can still play tomorrow is what you have learned.",
        ]),
        text("The steps the app gives you for each song follow this pattern. You can skip any step, but the slow steps are where the learning happens."),
    ]),
])

# ---------------------------------------------------------------- Music theory

unit("M1", "musicTheory", 1, "Rhythm and meter", "How long notes last and how beats are grouped.", [
    lesson("m1.1", "Note values and time signatures", "Whole, half, quarter, eighth, and what the two numbers mean.", 8, ["m.rhythm"], [
        text("Each note value lasts half as long as the one before: a whole note equals two half notes, a half note equals two quarter notes, a quarter note equals two eighth notes, and an eighth equals two sixteenths."),
        text("A dot after a note adds half of its length again. A dotted half note lasts three quarter notes; a dotted quarter lasts three eighths."),
        text("A time signature has two numbers. The top number says how many beats are in each measure. The bottom number says which note value gets one beat: 4 means a quarter note. So 3/4 means three quarter-note beats in each measure."),
        choice("How many quarter notes last as long as one dotted half note?", ["Two", "Three", "Four", "Six"], 1, "A half note is two quarters, and the dot adds half again: three."),
        choice("In 4/4 time, how many eighth notes fill one measure?", ["Four", "Six", "Eight", "Sixteen"], 2, "Four quarter-note beats, two eighths in each: eight."),
        choice("A piece is in 3/4. Which of these fills exactly one measure?", ["A whole note", "A dotted half note", "Two half notes", "Four quarter notes"], 1, "Three quarter beats equal one dotted half note."),
        text("Some tunes begin before the first full measure. Those opening notes are called a pickup, and the last measure of the piece is shortened to make up for them."),
        song("amazing-grace", "Amazing Grace is in 3/4 and starts with a one-beat pickup."),
    ]),
    lesson("m1.2", "Six-eight time", "Two big beats, each divided in three.", 6, ["m.compoundMeter"], [
        text("In 6/8 there are six eighth notes in a measure, but they are felt in two groups of three. You count two beats per measure, and each beat is a dotted quarter note."),
        text("That grouping is what separates 6/8 from 3/4. Both hold six eighth notes, but 3/4 has three beats divided in two, and 6/8 has two beats divided in three."),
        choice("How many main beats do you feel in a measure of 6/8?", ["Two", "Three", "Six", "Eight"], 0, "Two dotted-quarter beats, each made of three eighths."),
        choice("Which note gets one main beat in 6/8?", ["An eighth note", "A quarter note", "A dotted quarter note", "A half note"], 2, "Three eighths make a dotted quarter."),
        song("greensleeves", "Greensleeves is in 6/8: listen for long–short, long–short in each beat."),
    ]),
])

unit("M2", "musicTheory", 2, "Intervals", "The distance between two notes, by name and by ear.", [
    lesson("m2.1", "Naming intervals", "Count the letter names, then count the half steps.", 10, ["m.intervals"], [
        text("An interval is the distance from one note to another. Its number comes from counting letter names, including both ends: C up to E is C, D, E, so it is a third. C up to G is a fifth."),
        text("The number alone is not enough, because thirds come in two sizes. Count half steps to find the quality. A major third is four half steps; a minor third is three. A perfect fifth is seven half steps; a perfect fourth is five."),
        keyboard([60, 64, 67], ["C", "E", "G"], "C to E is a major third. C to G is a perfect fifth."),
        choice("What is the interval from C up to E?", ["Major second", "Minor third", "Major third", "Perfect fourth"], 2, "Three letter names (C, D, E) and four half steps: a major third."),
        choice("How many half steps are in a perfect fifth?", ["Five", "Six", "Seven", "Eight"], 2, "Seven half steps, for example C up to G."),
        gen("intervalName", 6, "Name each interval.", semitones=[2, 3, 4, 5, 7, 12]),
        gen("intervalPlay", 5, "Now play the note the app asks for.", semitones=[2, 3, 4, 5, 7]),
    ]),
    lesson("m2.2", "Hearing intervals", "Tell a third from a fifth by sound.", 8, ["m.intervals"], [
        text("Each interval has its own sound. A major third sounds bright and settled, like the start of a major chord. A minor third sounds darker. A perfect fifth sounds open and hollow. An octave sounds like the same note, higher."),
        text("The app plays two notes, one after the other and then together. Choose the interval you hear. You can listen as many times as you like."),
        gen("earInterval", 8, semitones=[3, 4, 7, 12]),
        text("When you can tell these four apart reliably, the next step is to add the perfect fourth and the major second."),
        gen("earInterval", 8, semitones=[2, 3, 4, 5, 7, 12]),
    ]),
])

unit("M3", "musicTheory", 3, "Keys", "Major and minor scales, key signatures, and how keys are related.", [
    lesson("m3.1", "How a major scale is built", "One pattern of whole and half steps gives every major scale.", 8, ["m.majorKeys"], [
        text("Every major scale follows the same pattern of steps: whole, whole, half, whole, whole, whole, half. Start on C and the pattern lands on white keys only. Start on any other note and you need black keys to keep the pattern."),
        scale("C", "major", "right"),
        text("Each letter name is used exactly once. That is why G major has F♯ rather than G♭: the scale already has a G, and it needs some kind of F."),
        scale("G", "major", "right", "G major: the seventh note is F♯."),
        choice("Where are the half steps in a major scale?", ["Between notes 2–3 and 6–7", "Between notes 3–4 and 7–8", "Between notes 1–2 and 5–6", "Between notes 4–5 and 7–8"], 1,
               "Whole, whole, half, whole, whole, whole, half: the half steps fall between 3–4 and 7–8."),
        gen("scaleNotes", 6, "Work out the note from the pattern.", keys=["C", "G", "D", "F", "Bb", "A"]),
    ]),
    lesson("m3.2", "Key signatures", "Sharps and flats arrive in a fixed order.", 8, ["m.majorKeys"], [
        text("A key signature at the start of each line tells you which notes are sharp or flat throughout the piece, so they do not have to be marked every time."),
        text("Sharps are always added in the same order: F, C, G, D, A, E, B. Each new sharp key starts a fifth higher than the last: C (none), G (one), D (two), A (three), E (four)."),
        text("Flats are added in the opposite order: B, E, A, D, G, C, F. Each new flat key starts a fifth lower: C (none), F (one), B♭ (two), E♭ (three), A♭ (four). Arranged in a ring, this is the circle of fifths."),
        choice("Which sharp is added first?", ["C♯", "F♯", "G♯", "B♯"], 1, "The order of sharps starts with F♯. G major has just that one."),
        choice("D major has two sharps. Which are they?", ["F♯ and C♯", "F♯ and G♯", "C♯ and D♯", "B♭ and E♭"], 0, "The first two sharps in order: F♯ and C♯."),
        gen("keySignature", 8, keys=["C", "G", "D", "A", "E", "F", "Bb", "Eb"]),
    ]),
    lesson("m3.3", "Minor keys", "Every major key has a minor partner with the same signature.", 8, ["m.minorKeys"], [
        text("Each major key shares its key signature with one minor key, called its relative minor. The relative minor starts on the sixth note of the major scale, which is three half steps below the major keynote. C major and A minor share a signature; so do G major and E minor."),
        scale("A", "naturalMinor", "right", "A natural minor: the notes of C major, starting on A."),
        text("Minor-key music usually raises the seventh note by a half step so that it leads firmly back to the keynote. The key signature does not show this, so it appears as a sharp or natural written in the music. In A minor it is G♯."),
        choice("What is the relative minor of C major?", ["C minor", "E minor", "A minor", "D minor"], 2, "The sixth note of C major is A."),
        choice("What is the relative minor of G major?", ["E minor", "B minor", "G minor", "D minor"], 0, "The sixth note of G major is E. Both keys have one sharp."),
        gen("keySignature", 5, "Minor keys use their relative major's signature.", keys=["Am", "Em", "Dm", "Bm", "Gm"]),
        song("greensleeves", "Greensleeves is in A minor."),
        song("fur-elise", "Für Elise is in A minor too: look for the raised seventh, G♯."),
    ]),
])

unit("M4", "musicTheory", 4, "Chords", "How chords are built, how they belong to a key, and the progressions you meet most.", [
    lesson("m4.1", "Four kinds of triad", "Major, minor, diminished and augmented.", 10, ["m.triads"], [
        text("A triad stacks two thirds. The order of the thirds gives its quality. Major: a major third with a minor third on top. Minor: a minor third with a major third on top. Diminished: two minor thirds. Augmented: two major thirds."),
        chords([chord("C"), chord("C", "minor"), chord("C", "diminished"), chord("C", "augmented")], ["major", "minor", "diminished", "augmented"]),
        text("Chord symbols name the root and the quality. A letter alone means major (C). A small m means minor (Cm). Then dim and aug."),
        choice("Which notes make a D minor chord?", ["D – F♯ – A", "D – F – A", "D – F – A♭", "D – G – A"], 1, "A minor third above D is F, and a major third above F is A."),
        gen("chordSpell", 6, "Choose the notes of each chord.", keys=["C", "G", "F", "D", "A", "E", "Bb"], qualities=["major", "minor"]),
        text("Now by ear. The app plays a chord; decide whether it is major or minor."),
        gen("earChord", 8, qualities=["major", "minor"]),
    ]),
    lesson("m4.2", "Chords in a key", "Build a triad on each note of the scale and number them.", 10, ["m.roman"], [
        text("Build a triad on each note of a major scale, using only notes of that scale, and you get seven chords. They are numbered with Roman numerals. Capital numerals are major chords and small ones are minor."),
        chords([chord("C"), chord("D", "minor"), chord("E", "minor"), chord("F"), chord("G"), chord("A", "minor"), chord("B", "diminished")],
               ["I", "ii", "iii", "IV", "V", "vi", "vii°"], "The seven chords of C major."),
        text("The pattern is the same in every major key: I, IV and V are major; ii, iii and vi are minor; vii is diminished. So if you know a song as I–IV–V, you can play it in any key."),
        text("I is home. V pulls strongly back to I. IV moves away from home more gently."),
        choice("In any major key, which three chords are major?", ["I, ii and iii", "I, IV and V", "ii, iii and vi", "IV, V and vi"], 1, "I, IV and V are the three major chords."),
        gen("romanName", 6, keys=["C", "G", "F", "D"], degrees=[1, 2, 4, 5, 6]),
        gen("romanPlay", 6, "Play each chord. Any position is fine.", keys=["C", "G", "F", "D"], degrees=[1, 4, 5, 6]),
    ]),
    lesson("m4.3", "Progressions you will meet everywhere", "I–IV–V–I and I–V–vi–IV.", 10, ["m.cadences", "m.roman"], [
        text("A few chord patterns turn up in thousands of pieces. The most basic is I–IV–V–I: leave home, move away, build tension, come back."),
        progression("Play I–IV–V–I in C major.", [chord("C"), chord("F"), chord("G"), chord("C")], ["I", "IV", "V", "I"],
                    "C – F – G – C. The move from V to I at the end is called an authentic cadence, the strongest ending in tonal music."),
        text("The ending V–I sounds finished. Ending on V instead sounds like a question and is called a half cadence. IV–I is the gentle plagal cadence, the sound of Amen."),
        progression("Play I–IV–V–I in G major.", [chord("G"), chord("C"), chord("D"), chord("G")], ["I", "IV", "V", "I"]),
        text("A second pattern, I–V–vi–IV, is behind a great many popular songs."),
        progression("Play I–V–vi–IV in C major.", [chord("C"), chord("G"), chord("A", "minor"), chord("F")], ["I", "V", "vi", "IV"], "C – G – Am – F."),
        choice("Which pair of chords makes the strongest ending?", ["IV to I", "V to I", "I to V", "ii to iii"], 1, "V to I is the authentic cadence."),
        song("canon-in-d", "The Canon in D repeats one eight-chord pattern throughout: I–V–vi–iii–IV–I–IV–V."),
    ]),
    lesson("m4.4", "Seventh chords", "Add one more third on top of a triad.", 8, ["m.seventhChords"], [
        text("Stack one more third on a triad and you get a four-note seventh chord. The most important is the dominant seventh, built on the fifth note of the key: a major triad with a minor seventh above the root. In C major it is G7: G, B, D, F."),
        chords([chord("G", "dominant7"), chord("C")], ["V7", "I"], "G7 pulls to C even more strongly than plain G."),
        text("Two others are common. A major seventh chord (Cmaj7: C, E, G, B) sounds soft and open. A minor seventh chord (Dm7: D, F, A, C) is the usual chord on ii."),
        choice("Which notes make G7?", ["G – B – D – F♯", "G – B♭ – D – F", "G – B – D – F", "G – B – D♯ – F"], 2, "A G major triad (G, B, D) plus F, a minor seventh above G."),
        play_chord("Play G7.", chord("G", "dominant7")),
        play_chord("Play C major seventh (Cmaj7).", chord("C", "major7")),
        play_chord("Play D minor seventh (Dm7).", chord("D", "minor7")),
        gen("chordSpell", 5, keys=["C", "G", "D", "F", "A"], qualities=["dominant7", "major7", "minor7"]),
        song("prelude-in-c", "Bach's Prelude in C spells out one chord per measure. The second measure is a D minor seventh chord over C."),
        song("gymnopedie-1", "The opening of Gymnopédie No. 1 rocks between two major seventh chords."),
    ]),
])

os.makedirs(os.path.join(ROOT, "lessons"), exist_ok=True)
for f in os.listdir(os.path.join(ROOT, "lessons")):
    if f.endswith(".json"): os.remove(os.path.join(ROOT, "lessons", f))
with open(os.path.join(ROOT, "skills.json"), "w") as f:
    json.dump([dict(id=i, track=t, title=n, prerequisites=p) for i, t, n, p in SKILLS], f, indent=2, ensure_ascii=False); f.write("\n")
for u in UNITS:
    with open(os.path.join(ROOT, "lessons", u["id"] + ".json"), "w") as f:
        json.dump(u, f, indent=2, ensure_ascii=False); f.write("\n")
print(len(UNITS), "units,", sum(len(u["lessons"]) for u in UNITS), "lessons written")
