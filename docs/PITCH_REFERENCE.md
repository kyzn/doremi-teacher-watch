# Pitch reference and research notes

Companion to the implementation plan · 9 September 2026

## Frequency model

Fix **concert A4 = 440 Hz**. An octave doubles frequency. In twelve-tone equal temperament, a semitone has ratio `2^(1/12)`. A cent is 1/1200 octave. Use:

```text
frequencyHz = 440 × 2^(centsFromConcertA4 / 1200)
centsFromConcertA4 = 1200 × log2(frequencyHz / 440)

# For conventional MIDI numbering, possibly fractional:
frequencyHz = 440 × 2^((midiNote - 69) / 12)

# Measured error relative to a target:
errorCents = 1200 × log2(measuredHz / targetHz)
# Accept any octave in the beginner humming exercise:
classErrorCents = errorCents - 1200 × round(errorCents / 1200)
```

These relations follow [UNSW’s notes/frequencies explanation](https://newt.phys.unsw.edu.au/jw/notes.html). Reject nonpositive/nonfinite inputs. Keep full precision internally; round only displayed Hz. Do not add a constant number of Hz to transpose: intervals are frequency ratios.

A4 means a particular octave, not every A. A3 = 220 Hz and A5 = 880 Hz. With the proposed octave-independent grading those belong to the same note class, but the detector must still estimate a valid fundamental frequency.

## Twelve-tone reference octave

Calculated from the formula above; values are rounded to two decimals. Names here are **concert names**, independent of the instrument naming setting.

| Concert note | Standard syllable | Hz |
| --- | --- | ---: |
| C4 | Do | 261.63 |
| C♯4 / D♭4 | Do♯ / Re♭ | 277.18 |
| D4 | Re | 293.66 |
| D♯4 / E♭4 | Re♯ / Mi♭ | 311.13 |
| E4 | Mi | 329.63 |
| F4 | Fa | 349.23 |
| F♯4 / G♭4 | Fa♯ / Sol♭ | 369.99 |
| G4 | Sol | 392.00 |
| G♯4 / A♭4 | Sol♯ / La♭ | 415.30 |
| A4 | La | 440.00 |
| A♯4 / B♭4 | La♯ / Si♭ | 466.16 |
| B4 | Si | 493.88 |
| C5 | Do | 523.25 |

## Quarter-tone examples

An equal quarter tone is 50 cents, with ratio `2^(1/24)`. The frequency halfway in pitch between two tones is their geometric mean, not their arithmetic mean. The 24-note collection contains 24 distinct classes; do not count octave endpoints twice.

| Example | Hz | Meaning |
| --- | ---: | --- |
| A4 −50¢ | 427.47 | 50 cents below A4 |
| A4 | 440.00 | Reference |
| A4 +50¢ | 452.89 | Halfway in pitch from A4 to A♯4 |
| A♯4 | 466.16 | One semitone above A4 |

## User’s saz example: my Re sounds E

This profile shifts conventional named pitches by +200 cents. The following octave illustrates the mapping; the quiz may choose an octave-equivalent pitch in its playback register.

| Displayed syllable | Written letter | Concert sound | Hz |
| --- | --- | --- | ---: |
| Do | C4 | D4 | 293.66 |
| Re | D4 | E4 | 329.63 |
| Mi | E4 | F♯4 | 369.99 |
| Fa | F4 | G4 | 392.00 |
| Sol | G4 | A4 | 440.00 |
| La | A4 | B4 | 493.88 |
| Si | B4 | C♯5 | 554.37 |

Here, written La4 sounds B4 at 493.88 Hz. **Concert** A4 remains 440 Hz. This is transposition, not changing the reference tuning. An instrument reference selector can work in pitch classes, with octave equivalence handled explicitly.

## What the research supports—and what still needs validation

| Source | Finding used in the plan |
| --- | --- |
| [Sierra College: Solfège Methods, Lauren C. Sharkey](https://human.libretexts.org/Courses/Sierra_College/Equipping_the_Musical_Ear/01:_Pitch/1.03:_Solfege_Methods) | Fixed syllables and key-relative degrees are different naming systems. The app uses Si for the seventh syllable as a product convention; this lesson uses Ti. |
| [Benli: bağlama positions and La-based representative notation, 2025](https://dergipark.org.tr/tr/pub/konservatoryum/article/1789342) | Tuning, playing positions, and representative note naming need explicit relationships. The user’s Re→E example drives our product profile; the paper is not a universal tuning prescription. |
| [İnanıcı: microtonal intervals in bağlama teaching, 2021](https://dergipark.org.tr/tr/download/article-file/1523486) | Fret relationships and microtonal practice are more complex than a universal equal-quarter-tone grid. A sourced future preset is preferable to claiming that 24 equal steps reproduce all saz intonation. |
| [UNSW: note names, MIDI numbers, frequencies](https://newt.phys.unsw.edu.au/jw/notes.html) | Logarithmic pitch/frequency conversion and the A4 reference used for our calculated tables. |
| [Apple: AVAudioEngine inputNode](https://developer.apple.com/documentation/avfaudio/avaudioengine/inputnode) | A recording tap can access input; check the actual hardware format before enabling analysis. |
| [YIN paper, de Cheveigné & Kawahara, 2002](https://pubmed.ncbi.nlm.nih.gov/12002874/) | A candidate fundamental-frequency algorithm for single-voice pitch estimation. It is not evidence that our future watch implementation is already accurate. |

Also inspected locally: Metronome’s audio engine/settings; `_newapps/applewatch` packaging and compatibility notes; watchOS 26.5 SDK AVFAudio headers (`inputNode` and recording-permission APIs available from watchOS 4). Proposed watchOS 8 compatibility still needs a build check during implementation.

The +50-cent label conventions, tone register/duration, 3-second recording window, and ±35/±15-cent grading thresholds are product/engineering choices, not cultural standards or measured device performance. In particular, quarter-tone capture accuracy is unproven until the physical-watch experiment passes. No audio recordings, app code, or hardware experiments were made for this planning task.
