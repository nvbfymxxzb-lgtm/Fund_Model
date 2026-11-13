#!/usr/bin/env python3
"""Writes the bundled song files. Edit the songs here, then run this script.

Notation: see PianoCore/Sources/MusicModel/TinyNotation.swift.
Every song here is a public-domain composition or traditional tune, arranged for this app.
None of them has been checked by a teacher: review state is "draft".
"""
import json, os

OUT = os.path.join(os.path.dirname(__file__), "..", "PianoCore", "Sources", "Curriculum", "Content", "songs")
RIGHTS_TRAD = "Traditional tune, public domain. Arrangement written for this app."
SONGS = []

def song(id, level, title, composer, about, skills, key, time, tempo, rh, lh, minor=False, pickup=False, rh2=None, lh2=None,
         rights=RIGHTS_TRAD, anchor=None, phrases=None):
    src = dict(title=title, composer=composer, keyFifths=key, minor=minor, time=time, tempo=tempo, pickup=pickup,
               rh=" ".join(rh.split()), lh=" ".join(lh.split()))
    if rh2: src["rh2"] = " ".join(rh2.split())
    if lh2: src["lh2"] = " ".join(lh2.split())
    d = dict(id=id, level=level, about=about, skillIds=skills, reviewState="draft", rights=rights, source=src)
    if anchor: d["levelAnchor"] = anchor
    if phrases: d["phrases"] = phrases
    SONGS.append(d)

C, G7, F = "[C3 E3 G3]", "[B2 D3 G3]", "[C3 F3 A3]"

song("ode-to-joy", 1, "Ode to Joy", "Ludwig van Beethoven, arr.",
     "The melody stays under five fingers while the left hand holds three-note chords. A good first piece for changing chords smoothly: C in root position and G with B at the bottom.",
     ["p.blockChords", "p.inversions", "m.roman"], 0, "4/4", 100,
     """E4:q E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4:q. D4:e D4:h |
        E4:q E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4:q. C4:e C4:h |
        D4:q D4 E4 C4 | D4 E4:e F4 E4:q C4 | D4 E4:e F4 E4:q D4 | C4 D4 G3:h |
        E4:q E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4:q. C4:e C4:h""",
     f"""{C}:w | {G7}:w | {C}:w | {C}:h {G7}:h |
         {C}:w | {G7}:w | {C}:w | {G7}:h {C}:h |
         {G7}:h {C}:h | {G7}:h {C}:h | {G7}:h {C}:h | {C}:h {G7}:h |
         {C}:w | {G7}:w | {C}:w | {G7}:h {C}:h""",
     rights="Melody by Beethoven (died 1827), public domain. Arrangement written for this app.")

song("when-the-saints", 1, "When the Saints Go Marching In", "Traditional, arr.",
     "Three chords, C, F and G, played close together so the left hand barely moves. The tune starts before the first full measure (a pickup).",
     ["p.blockChords", "p.inversions", "m.roman", "m.rhythm"], 0, "4/4", 112,
     """C4:q E4 F4 | G4:w | r:q C4 E4 F4 | G4:w | r:q C4 E4 F4 | G4:h E4 | C4:h E4 | D4:w |
        r:q E4 E4 D4 | C4:h. C4:q | E4:h G4 | G4:h F4~ | F4:h E4:q F4 | G4:h E4 | C4:h D4 | C4:w""",
     f"""r:h. | {C}:w | {C}:w | {C}:w | {C}:w | {C}:w | {C}:w | {G7}:w |
         {G7}:w | {C}:w | {C}:w | {F}:w | {F}:w | {C}:w | {C}:h {G7}:h | {C}:w""",
     pickup=True)

song("amazing-grace", 1, "Amazing Grace", "Traditional, arr.",
     "A slow tune in three-time with open fifths in the left hand. Listen for the long notes and count them fully.",
     ["p.legato", "m.rhythm", "m.majorKeys"], 1, "3/4", 84,
     """D4:q | G4:h B4:e G4 | B4:h A4:q | G4:h E4:q | D4:h D4:q | G4:h B4:e G4 | B4:h A4:q | D5:h.~ | D5:h B4:q |
        D5:q. B4:e D5 B4 | G4:h D4:q | E4:q. G4:e G4 E4 | D4:h D4:q | G4:h B4:e G4 | B4:h A4:q | G4:h.~ | G4:h""",
     """r:q | [G2 D3]:h. | [G2 D3]:h. | [C3 G3]:h. | [G2 D3]:h. | [G2 D3]:h. | [G2 D3]:h. | [D3 A3]:h. | [D3 A3]:h. |
        [G2 D3]:h. | [G2 D3]:h. | [C3 G3]:h. | [G2 D3]:h. | [G2 D3]:h. | [G2 D3]:h [D3 A3]:q | [G2 D3]:h.~ | [G2 D3]:h""",
     pickup=True)

song("canon-in-d", 2, "Canon in D (theme)", "Johann Pachelbel, arr.",
     "Eight chords that repeat while the melody changes above them. The left hand walks the bass in half notes; the last section moves the right hand in quarters.",
     ["m.roman", "m.majorKeys", "p.handIndependence"], 2, "4/4", 72,
     """F#5:h E5 | D5:h C#5 | B4:h A4 | B4:h C#5 |
        D5:h C#5 | B4:h A4 | G4:h F#4 | G4:h E4 |
        F#5:q D5 E5 C#5 | D5 B4 C#5 A4 | B4 G4 A4 F#4 | G4 B4 A4 C#5 | D5:w""",
     """D3:h A2 | B2:h F#2 | G2:h D3 | G2:h A2 |
        D3:h A2 | B2:h F#2 | G2:h D3 | G2:h A2 |
        D3:h A2 | B2:h F#2 | G2:h D3 | G2:h A2 | [D3 A3]:w""",
     rights="Composition by Pachelbel (died 1706), public domain. Simplified arrangement written for this app.")

FB, CB, BB = "F3:q A3 C4 A3", "E3:q G3 C4 G3", "F3:q Bb3 D4 Bb3"
song("auld-lang-syne", 2, "Auld Lang Syne", "Traditional, arr.",
     "The left hand plays broken chords in steady quarters under a dotted-rhythm tune. Keep the left hand quieter than the melody.",
     ["p.brokenChords", "p.dynamics", "m.rhythm", "m.roman"], -1, "4/4", 88,
     """C4:q | F4:q. F4:e F4:q A4 | G4:q. F4:e G4:q A4 | F4:q. F4:e A4:q C5 | D5:h. D5:q |
        C5:q. A4:e A4:q F4 | G4:q. F4:e G4:q A4 | F4:q. D4:e D4:q C4 | F4:h. D5:q |
        C5:q. A4:e A4:q F4 | G4:q. F4:e G4:q D5 | C5:q. A4:e A4:q C5 | D5:h. D5:q |
        C5:q. A4:e A4:q F4 | G4:q. F4:e G4:q A4 | F4:q. D4:e D4:q C4 | F4:h.""",
     f"""r:q | {FB} | {CB} | {FB} | {BB} | {FB} | {CB} | F3:q Bb3 E3 C4 | F3:q A3 C4:h |
         {FB} | {CB} | {FB} | {BB} | {FB} | {CB} | F3:q Bb3 E3 C4 | [F3 A3 C4]:h.""",
     pickup=True)

WC, WG, WF = "C3:q [E3 G3] [E3 G3]", "B2:q [F3 G3] [F3 G3]", "C3:q [F3 A3] [F3 A3]"
song("brahms-lullaby", 3, "Lullaby (Wiegenlied)", "Johannes Brahms, arr.",
     "A waltz pattern in the left hand: one low note, then two soft chords. The left hand has to jump while the right hand sings.",
     ["p.handIndependence", "p.dynamics", "p.legato", "m.rhythm"], 0, "3/4", 80,
     """E4:e E4 | G4:q. E4:e E4:q | G4:h E4:e G4 | C5:q. B4:e A4:q | A4:q G4 D4:e E4 | F4:q D4 D4:e E4 | F4:h D4:e F4 | B4:q A4 G4 | B4:q C5 C4:e C4 |
        C5:h A4:e F4 | G4:h E4:e C4 | F4:q G4 A4 | G4:h C4:e C4 | C5:h A4:e F4 | G4:h E4:e C4 | F4:q. E4:e D4:q | C4:h""",
     f"""r:q | {WC} | {WC} | {WC} | {WG} | {WG} | {WG} | {WG} | {WC} |
         {WF} | {WC} | {WG} | {WC} | {WF} | {WC} | {WG} | [C3 E3 G3]:h""",
     pickup=True, rights="Melody by Brahms (died 1897), public domain. Transposed and arranged for this app.")

song("greensleeves", 3, "Greensleeves", "Traditional (16th century), arr.",
     "A minor-key tune in six-eight time, with the long–short–long lilt that this meter is known for. Watch for the G sharp and F sharp.",
     ["m.compoundMeter", "m.minorKeys", "p.legato"], 0, "6/8", 60,
     """A4:e | C5:q D5:e E5:e. F5:s E5:e | D5:q B4:e G4:e. A4:s B4:e | C5:q A4:e A4:e. G#4:s A4:e | B4:q G#4:e E4:q A4:e |
        C5:q D5:e E5:e. F5:s E5:e | D5:q B4:e G4:e. A4:s B4:e | C5:e. B4:s A4:e G#4:e. F#4:s G#4:e | A4:q. A4:q. |
        G5:q. G5:e. F#5:s E5:e | D5:q B4:e G4:e. A4:s B4:e | C5:q A4:e A4:e. G#4:s A4:e | B4:q G#4:e E4:q. |
        G5:q. G5:e. F#5:s E5:e | D5:q B4:e G4:e. A4:s B4:e | C5:e. B4:s A4:e G#4:e. F#4:s G#4:e | A4:q. A4:q""",
     """r:e | [A2 E3]:h. | [G2 D3]:h. | [F2 C3]:h. | [E2 B2]:h. |
        [A2 E3]:h. | [G2 D3]:h. | [A2 E3]:q. [E2 B2]:q. | [A2 E3]:q. [A2 E3]:q. |
        [C3 G3]:h. | [G2 D3]:h. | [F2 C3]:h. | [E2 B2]:h. |
        [C3 G3]:h. | [G2 D3]:h. | [A2 E3]:q. [E2 B2]:q. | [A2 E3]:q. [A2 E3]:q""",
     minor=True, pickup=True)

song("minuet-in-g", 3, "Minuet in G (first half)", "Christian Petzold (from the Anna Magdalena Notebook)",
     "Two independent lines: the left hand has its own tune rather than chords. Play the quarter notes lightly detached and the eighths smoothly.",
     ["p.handIndependence", "p.scales", "m.majorKeys"], 1, "3/4", 108,
     """D5:q G4:e A4 B4 C5 | D5:q G4 G4 | E5:q C5:e D5 E5 F#5 | G5:q G4 G4 | C5:q D5:e C5 B4 A4 | B4:q C5:e B4 A4 G4 | F#4:q G4:e A4 B4 G4 | B4:q A4:h |
        D5:q G4:e A4 B4 C5 | D5:q G4 G4 | E5:q C5:e D5 E5 F#5 | G5:q G4 G4 | C5:q D5:e C5 B4 A4 | B4:q C5:e B4 A4 G4 | A4:q B4:e A4 G4 F#4 | G4:h.""",
     """[G3 B3 D4]:h A3:q | B3:h. | C4:h. | B3:h. | A3:h. | G3:h. | D4:q B3 G3 | D4:q D3:e C4 B3 A3 |
        B3:h A3:q | G3:q B3 G3 | C4:h. | B3:q C4:e B3 A3 G3 | A3:h F#3:q | G3:h B3:q | C4:q D4 D3 | G3:h G2:q""",
     rights="Composition by Petzold (died 1733), public domain. Written out from memory for this app: check it against a printed edition.",
     anchor="Commonly set at early grades in graded piano syllabuses (to verify)")

def prelude_bar(n1, n2, a, b, c):
    rh = f"r:e {a}:s {b} {c} {a} {b} {c} r:e {a}:s {b} {c} {a} {b} {c}"
    lh = f"{n1}:s {n2} r:e r:q {n1}:s {n2} r:e r:q"
    return rh, lh
bars = [("C4","E4","G4","C5","E5"), ("C4","D4","A4","D5","F5"), ("B3","D4","G4","D5","F5"), ("C4","E4","G4","C5","E5"),
        ("C4","E4","A4","E5","A5"), ("C4","D4","F#4","A4","D5"), ("B3","D4","G4","D5","G5"), ("B3","C4","E4","G4","C5"),
        ("A3","C4","E4","G4","C5"), ("D3","A3","D4","F#4","C5"), ("G3","B3","D4","G4","B4")]
pr = [prelude_bar(*b) for b in bars]
song("prelude-in-c", 4, "Prelude in C (opening)", "Johann Sebastian Bach, BWV 846, simplified",
     "One broken chord per measure, shared between the hands: the left hand plays the first two notes and the right hand answers with three. The aim is a perfectly even stream of notes.",
     ["p.brokenChords", "p.legato", "m.seventhChords", "m.roman"], 0, "4/4", 60,
     " | ".join(p[0] for p in pr) + " | [E4 G4 C5]:w", " | ".join(p[1] for p in pr) + " | [C3 G3]:w",
     rights="Composition by J. S. Bach (died 1750), public domain. Measures 1–11 with the held notes simplified and a closing chord added for this app.")

GY_G = ("G2:h.", "r:q [B3 D4 F#4]:h"); GY_D = ("D2:h.", "r:q [A3 C#4 F#4]:h")
gy = [GY_G, GY_D] * 6
song("gymnopedie-1", 4, "Gymnopédie No. 1 (opening)", "Erik Satie",
     "The left hand leaps from a low bass note to a chord in every measure, so use the pedal to join them: change it on each bass note. The melody floats slowly on top.",
     ["p.pedal", "p.handIndependence", "p.dynamics", "m.seventhChords"], 2, "3/4", 72,
     "r:h. | r:h. | r:h. | r:h. | r:q F#5:q A5 | G5:q F#5 C#5 | B4:q C#5 D5 | A4:h. | F#4:h.~ | F#4:h.~ | F#4:h.~ | F#4:h.",
     " | ".join(g[0] for g in gy), lh2=" | ".join(g[1] for g in gy),
     rights="Composition by Satie (died 1925), public domain in most countries: check your own. First 12 measures written out from memory for this app.")

song("fur-elise", 5, "Für Elise (theme)", "Ludwig van Beethoven",
     "Fast alternating notes in the right hand and broken chords that pass from the left hand up into the right. Learn the hand-over between left and right slowly.",
     ["p.brokenChords", "p.handIndependence", "m.minorKeys", "p.pedal"], 0, "3/8", 60,
     """E5:s D#5 | E5:s D#5 E5 B4 D5 C5 | A4:e r:s C4:s E4 A4 | B4:e r:s E4:s G#4 B4 | C5:e r:s E4:s E5 D#5 |
        E5:s D#5 E5 B4 D5 C5 | A4:e r:s C4:s E4 A4 | B4:e r:s E4:s C5 B4 | A4:q""",
     """r:e | r:q. | A2:s E3 A3 r:s r:e | E2:s E3 G#3 r:s r:e | A2:s E3 A3 r:s r:e |
        r:q. | A2:s E3 A3 r:s r:e | E2:s E3 G#3 r:s r:e | A2:s E3 A3:e""",
     minor=True, pickup=True,
     rights="Composition by Beethoven (died 1827), public domain. Opening theme written out from memory for this app: check it against a printed edition.")

os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith(".json"): os.remove(os.path.join(OUT, f))
for s in SONGS:
    with open(os.path.join(OUT, s["id"] + ".json"), "w") as f:
        json.dump(s, f, indent=2, ensure_ascii=False); f.write("\n")
print(len(SONGS), "songs written")
