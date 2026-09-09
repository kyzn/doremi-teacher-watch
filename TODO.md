# Deferred from v1

Decided with the product owner on 9 September 2026. Each item is out of the first
release on purpose, not forgotten.

| Item | Why deferred | Notes for later |
|---|---|---|
| Note → Hum (microphone pitch matching) | Needs a wrist prototype that passes the acceptance gates in IMPLEMENTATION_PLAN.md before it can be scored honestly. | Menu row hidden in v1. Stats keep a separate humming bucket so adding it needs no migration. |
| Movable Do naming mode | Most confusing of the three naming modes; Standard and My instrument cover the saz use case. | Keep `NoteNaming` shaped so a third mode slots in without touching the quiz. |
| Equal quarter tones (24-note set) in listening | Labels like "Re♯ +50¢" need two-line buttons that are unproven on the 40mm layout. | Ship 7 and 12 first. Pitch collection already stores cents, so 24 is a data addition. |
| Quarter-tone humming | Depends on both items above. | Tighter ±15-cent gate; test 50-cent neighbours separately. |
| Sourced saz intonation preset | No verified cents table yet. | Needs a list reviewed against the user's teacher or instrument. |

# Decisions log

- Reference sound removed entirely (9 September 2026): the anchor-then-target playback felt
  like two unexplained sounds on the wrist. Hear → Guess plays only the hidden note. If a
  learner needs an anchor later, add it back as an explicit "Hear Do" button, not automatic
  playback.
- Instrument naming (My instrument) is available only with Do Re Mi names; A B C always means
  concert pitch.
- No sharps/flats preference. Altered pitches use the conventional songbook spelling C♯, E♭,
  F♯, G♯, B♭; feedback can show the other name.

- Playback register: **C5–B5**. On the wrist, octave 4 was barely audible at full volume and octave 6 cracked from about F6. Decided 9 September 2026.
- Note names: user-selectable letters or syllables, default Standard naming. In Japanese the
  syllable UI shows katakana (ドレミファソラシ).
- Names: EN "Doremi Teacher Watch Special", JA "ドレミ先生 ウォッチ", TR "Doremi Hocası Kolunda";
  under the icon "Doremi Teacher", "ドレミ先生", "Doremi Hocası".
- UI rules carried over from Morse Teacher: practice screens fit one display without
  scrolling, no page titles, first sound plays automatically, crown volume on every practice
  screen, icon-only secondary buttons, three-page stats.
