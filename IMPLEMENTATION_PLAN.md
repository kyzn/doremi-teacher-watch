# Doremi Teacher — Apple Watch implementation plan

Planning draft · 9 September 2026 · No app implementation yet

## Product direction

Yes: a watch can play a pitched tone, offer four note-name answers, and use its microphone to estimate a hummed note. Listening is straightforward; reliable humming assessment needs an early hardware prototype. Keep everything offline, with short foreground sessions and no account.

Main menu: **Hear → Guess**, **Note → Hum**, **Stats**, **Settings**. Build listening, naming settings, and stats first. Include humming once the device checks below pass. Fix the concert reference at **A4 = 440 Hz** for v1.

[Screen concepts](docs/watch-wireframes.svg) · [Frequency and research notes](docs/PITCH_REFERENCE.md)

## The important distinction: a name is not a frequency

The user’s concrete saz example is: **the bottom string is called Re even when tuned to concert E**. Model this as a consistent transposition of familiar note names. Do not hard-code “Re means 293.66 Hz,” or assume the string must always sound D.

Three separate concepts belong in the model:

- **Name style:** letters or syllables.
- **Naming relationship:** standard names, transposed names, or movable Do.
- **Pitch collection/tuning:** seven notes, twelve equal-tempered pitches, or twenty-four equal quarter tones.

Moving the names must not silently change A4’s concert frequency. Adding microtones must not silently change the naming relationship.

### Naming settings

| Setting | Proposed choices and behavior |
| --- | --- |
| **Note names** | `A B C` or `Do Re Mi`. Use Do/Re/Mi/Fa/Sol/La/Si in the syllable UI. |
| **Names follow** | `Standard pitches` (default), `My instrument`, or `The key (movable Do)`. Mutually exclusive. |
| **My instrument → Reference name** | Default `Re`; can choose another natural syllable if needed. |
| **My instrument → Sounds like** | Concert letter pitch, default D for Re. Example: **My Re sounds like E**. Show the equivalent `D → E` when letters are selected. |
| **The key → Do is** | Concert tonic, e.g. D. V1 uses a major-scale framework; do not imply automatic makam or minor-mode support. |
| **Notes to practice** | `Seven notes`, `With sharps/flats (12)`, `Equal quarter tones (24)`. |
| **Accidental names** | `Prefer sharps` / `Prefer flats`, shown for expanded note sets. This changes spelling, not sound. |
| **Reference sound** | On by default; advanced learners can turn it off outside movable-Do mode. |

**Standard:** C = Do, D = Re, E = Mi. In the instrument setting **Re sounds E**, the whole named pitch collection shifts up two semitones: Do sounds D, Re sounds E, Mi sounds F♯, Fa sounds G, Sol sounds A, La sounds B, Si sounds C♯. The preview is essential because it makes the setting understandable without knowing “transpose +2.” These are the consequences of this particular uniform shift, not a claim about every saz tuning or makam.

**Movable Do:** Do means the tonic of the selected key. In D major, Do = D, Re = E, Mi = F♯. This happens to give the same seven pitches as the example above, but expresses a different musical relationship. Keep separate internal modes and explanatory text. Fixed/movable solfège is described in [Sierra College’s solfège lesson](https://human.libretexts.org/Courses/Sierra_College/Equipping_the_Musical_Ear/01:_Pitch/1.03:_Solfege_Methods).

In instrument mode, switching syllables to letters gives **written** names (Re → D), while “Sounds like” always shows **concert** letters (E). In movable-Do mode, syllables show degrees and letters show the corresponding concert pitches. Show this distinction in settings, not on every quiz button. Never apply both transposition and movable-Do offsets together.

The instrument reference is a pitch class, not a required singing octave. Octaves are handled separately. First version shifts the entire collection uniformly; it is not a full fret/string/düzen editor. Research on bağlama distinguishes tuning/position from representative notation, supporting the need for this separation: [Benli, 2025](https://dergipark.org.tr/tr/pub/konservatoryum/article/1789342).

### Note sets and microtones

**Seven notes** means the seven unaltered names in the selected naming system. Under Re→E these sound D, E, F♯, G, A, B, C♯; “seven notes” does not mean the concert piano’s white keys in every mapping.

**With sharps/flats** includes all 12 unique pitch classes. C♯ and D♭ are the same answer sound in this equal-tempered mode. Never place both on one multiple-choice screen. Use one preferred spelling per pitch; feedback may show its alternate name. In movable Do, use explicit labels like Do♯ or Re♭ rather than introducing a second set of chromatic singing syllables.

**Equal quarter tones** adds the halfway pitches for 24 equally spaced pitches per octave, 50 cents apart. Use readable labels such as `Re +50¢` (accessibility: “Re raised by a quarter tone”). Canonical spelling: take each of the 12 base pitches in the selected naming system and add a second pitch 50 cents above it. Thus `Re♯ +50¢` is also possible. Explain this once in settings; avoid unfamiliar accidental glyphs that may not render on the watch.

Call this **equal quarter tones**, not “authentic saz tuning.” Bağlama research discusses unequal fret systems and differing proposals for 24 pitches; 24 equal divisions are only one option. See [İnanıcı, 2021](https://dergipark.org.tr/tr/download/article-file/1523486). A future saz preset needs an explicit, sourced list of cents/ratios and note labels, reviewed against the user’s teacher or instrument. Do not invent a universal koma-to-Hz table.

## Practice screens

### Hear → Guess

1. Choose a target from the active set, avoiding the previous pitch class, and three distinct distractor pitches. Shuffle the four buttons.
2. The learner taps **Play**. With Reference sound on, play the named anchor, pause, then play the hidden target. In standard mode the anchor is Do/C; in instrument mode it is the chosen reference (e.g. Re sounding E); in movable Do it is the tonic. Clearly label the anchor before playback.
3. After playback, enable four large answers in a 2×2 grid and **Replay**. Replays do not affect score. Do not reveal target frequency, name, or accessibility text early.
4. One tap locks the round and records one result. Feedback says **Correct** / **Not quite**, shows the expected name, and offers **Hear answer** and **Next**. In instrument mode, feedback can additionally show “Sounds E.”

A reference makes this useful for learners without absolute pitch: they can learn relationships to a known sound. Reference off is an optional harder exercise in pitch memory, not a promise to teach perfect pitch. Movable Do always retains the tonic reference because its labels depend on that context.

Use a sounding playback register around **C4–B4** initially, choosing one representative of each class after mapping. Keep that register stable and validate its audibility on the watch speaker. Do not grade octaves in v1. Use the same timbre and duration for all targets so those do not become answer clues. Expanded note labels may use two lines, not tiny text.

### Note → Hum

Default this to **pitch matching**, a useful attainable beginner task:

1. Show the target name and **Hear target**. The user hears the target before recording. This is deliberately assisted practice; showing a name alone would demand pitch memory.
2. After playback fully stops, enable **Start humming**. Request microphone permission only at first use, with a clear purpose string.
3. Listen for up to about 3 seconds. Show input activity and “Hold one steady note,” without live sharp/flat guidance during scoring.
4. Use a stable voiced segment to decide **Matched** / **Not quite**. Show higher/lower guidance afterward. Accept a comfortable octave: humming E3 can match target E4.
5. Silence, unstable sound, interruption, or low confidence gives **Couldn’t hear a steady note — Try again**, with no correct/wrong count. A confidently detected wrong note is a wrong answer. Next starts a new round.

Automatically finish when a stable segment has been captured; retain **Cancel**. A retry after a scored result is unscored practice, preventing repeated attempts at the same question from inflating totals. Provide Next explicitly.

A later “sing from the name without hearing it” challenge can be added as a separate difficulty with separate stats. V1 only needs assisted matching. Humming means estimating pitch, not recognizing whether the user said “Re”; no speech-recognition service is needed.

Quarter-tone humming should only be enabled after its tighter acceptance tests pass. Until then, when the 24-note set is selected, explain in Hum that this set supports listening only and offer a visible switch to 12 notes. Never silently round a quarter-tone target to a semitone.

### Stats

Swipe **Today / All time**. Each page shows correct, wrong, answered, and accuracy, with separate compact **Listening / Humming** sections so multiple-choice recognition and assisted singing are not conflated. Zero answers → accuracy `—`. Vertical scrolling handles larger text.

Store local versioned counters by mode and configuration (note set, naming mapping, reference on/off). Initial UI can aggregate within each mode; retained configuration buckets support future comparisons. Count only completed scored rounds, once per question ID. Replays, cancellations, capture failures, and practice retries do not count.

Use the local calendar date at submission. Recheck on foreground, submission, opening Stats, and midnight while visible. Reset Today on date change, preserve All time. A timezone date change starts a new Today bucket; no historical day restoration in this small first version. Save immediately after a result. Settings changes abandon an unfinished round and start fresh without scoring it.

## Audio and pitch detection approach

Generate a short PCM tone with attack/release ramps to avoid clicks. Reuse the Metronome project’s retained `AVAudioEngine` / player, audio-session handling, and cancellation approach, but omit looping, sync/calibration, and extended runtime. Start with a sine tone; test a consistent soft harmonic tone only if speaker audibility requires it. A synthesized frequency does not require a sampled instrument library.

The installed watchOS 26.5 SDK declares `AVAudioEngine.inputNode` available from watchOS 4. Apple documents recording taps and checking for a valid sample rate/channel count in its [inputNode documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine/inputnode). That establishes API feasibility, not proven detector quality on this watch.

For humming, configure a supported recording session and use a tap feeding a bounded audio buffer. Do analysis on a worker queue, not the audio callback or UI thread. Honor actual input sample rate; use an accumulated window around 80–100 ms with overlapping analysis. Start with a roughly 70–1000 Hz search range and validate comfortable voices. Expose no voice-range setting until needed.

Evaluate a YIN-style fundamental-frequency estimator, a published approach for speech/music [de Cheveigné & Kawahara, 2002](https://pubmed.ncbi.nlm.nih.gov/12002874/). Do not choose the largest FFT peak: it can be a harmonic. The detector should estimate pitch independently of the expected answer, then the grader compares results. Avoid “pulling” uncertain estimates toward the target.

Prototype thresholds, to be tuned on real recordings: approximately 600 ms of reliable pitch; standard-note tolerance ±35 cents; quarter-tone tolerance ±15 cents, always less than half the 50-cent separation. Require low enough variation to distinguish a sustained note from a slide, and sufficient periodicity/amplitude to reject noise. Aggregate pitches in log-frequency with octave-aware handling, not a mean of raw Hz across octave jumps. Handle borderline results consistently and test threshold boundaries.

Stop playback before capture, allow a brief output-tail gap (start around 250 ms), then reset capture buffers. Validate on actual routes; do not let the app’s speaker answer its own quiz. Built-in mic is the initial target. Test Bluetooth route changes separately; do not assume every headset behaves identically. Stop engine/tap on exit, wrist/app inactivity, interruption, and cancellation; invalidate stale completions. Return to a ready state requiring an explicit new playback/record tap.

Process mic audio in memory and discard it after the round. Store only scores and configuration. No recording library, uploads, or background listening. Denied microphone permission leaves listening and stats fully usable.

## Suggested implementation structure

| Component | Responsibility |
| --- | --- |
| `PitchMath` | Frequency/cents conversions and octave-independent comparison. |
| `PitchCollection` | 7/12/24-note definitions using precise cents and stable IDs. Future non-equal presets fit the same representation. |
| `NoteNaming` | Standard, instrument transposition, movable Do, spellings, and settings preview. |
| `QuestionGenerator` | Unique sounding choices, target selection, immutable per-round configuration. |
| `TonePlayer` | Finite tone/reference playback with completion and cancellation. |
| `PitchDetector` + `HumGrader` | Independent F0/confidence estimation, stable-segment selection, result classification. |
| `PracticeSession` | Ready/play/answer/record/feedback state; one result per question. |
| `SettingsStore` / `StatsStore` | Small versioned local snapshots; atomic logical updates on the main actor. |
| SwiftUI screens | Home, listening, humming, shared feedback, stats, settings and mapping preview. |

Use cents relative to concert A4 as the shared sound identity. Keep displayed/written pitch, sounding pitch, and octave explicit. Never grade by a translated string. Freeze settings for the round so a change cannot relabel an already playing question.

## Build order and acceptance gates

1. **Foundation + wrist experiment.** Use the [watch app templates](../_newapps/applewatch/templates/README.md) and [shipping notes](../_newapps/applewatch/README.md): watch app plus empty iOS distribution container, initially watchOS 8/iOS 15 like Metronome. Verify compatibility with the installed toolchain. Test tones across C4–B4, microphone input, and capture/playback transitions on a real watch. No app or archive is created by this planning task.
2. **Pitch/naming core.** Implement numeric mapping and preview first. Verify Re→E in both directions, label-style changes without frequency changes, seven-note transposition, and distinct quarter tones. Implement Standard and My instrument before the separate movable-Do option.
3. **Listening, settings, stats.** Deliver the complete four-choice experience for 7/12/24 sets, feedback, daily/lifetime counters, restart persistence, and accessible naming. Test no enharmonic duplicates or hidden answer leaks.
4. **Humming prototype → feature.** Test generated tones, harmonic-rich fixtures, silence/noise, real humming from several comfortable ranges, octave errors, drifting voices, and the app’s own playback tail. Ship standard-note humming only after reliable results; otherwise retain it as unfinished prototype work, not a misleadingly scored feature. Test 50-cent neighbors separately before enabling quarter-tone humming.
5. **Polish and release preparation.** Smallest/largest supported watch layouts, long/localized labels, microphone denial, route interruptions, battery/CPU during repeated short sessions, and watchOS compatibility checks. Reuse Metronome’s EN/JA/TR localization pattern; keep musical naming independent of UI language. Validate packaging, matched opaque icons, privacy/support pages, and App Store assets at release time.

Target prototype gates: clean generated-tone estimation within about 5 cents across the supported range; silence/noise never produces a passing answer in the test fixtures; stable semitone neighbors are rejected under ±35-cent grading; stable 50-cent neighbors are rejected under quarter-tone grading. Real-voice trial results must be reviewed separately—passing synthetic tests does not establish human accuracy. Record failures and tune thresholds before claiming support.

Out of v1: configurable A4, arbitrary makam/fret editors, polyphonic saz recognition, chord/melody transcription, instrument-specific timbres, perfect-pitch claims, cloud sync, and background recording. The architecture allows sourced saz intonation presets later without rewriting the quiz.
