# Doremi Teacher: state machines

Audit of 2026-11-13 at `310aae6` (1.1, build 16). Same method as Morse Teacher's
`docs/STATE_MACHINES.md`: list the fields that move together, write down the states they encode,
and try to reach each invalid combination through taps, callbacks, the watchdog retry, scene
changes, audio notifications and settings edits. Everything runs on the main actor. The only
cross-thread hop is the AVAudioPlayerNode completion, which returns through
`Task { @MainActor }`.

The listening round and the audio player are line-for-line ports of Morse Teacher's (with
`TonePlayer` in place of `MorseAudioPlayer`), so their tables match Morse's §1 and §3. They're
repeated here with Doremi's line numbers. The settings machine (§4) is Doremi's own.

**B** = confirmed bug, **G** = gap, **D** = design question.

**Status 2026-11-15: all findings fixed** (see "Issues" at the end). The tables below describe the
code as audited; §1's new shape is in the "After the fixes" note there.

---

## 1. Listening round: `ListeningSession`

Fields: `phase`, `isPlaying`, `hasHeardQuestion`, `playbackError`, `recordedQuestionID`,
`question` (frozen settings: naming, noteSet, target, choices).

| State | phase | isPlaying | hasHeard | error | UI |
|---|---|---|---|---|---|
| Fresh | awaitingPlayback | false | false | nil | "Play", answers locked |
| Failed | awaitingPlayback | false | false | message | red "Retry", answers locked |
| Playing (first or replay) | playing | true | either | nil | "Playing…" |
| Ready to answer | awaitingAnswer | false | true | nil | "Replay", answers open |
| Feedback | feedback(chosen) | false | true | nil | Hear again + Next |
| Feedback, replaying | feedback(chosen) | true | true | nil | Hear again disabled |

Invariants:
1. `phase == .playing` ⇔ the player holds this question's callback.
2. `phase == .awaitingAnswer` ⇒ heard in full, no error.
3. `phase == .feedback` ⇒ exactly one result recorded for `question.id`, in bucket
   (listening, `question.noteSet`).
4. A question's naming and note set are frozen when it's generated (`ListeningView.swift:10-13`),
   so a settings change can't relabel a sound that already played.

| From | Event | To | Code |
|---|---|---|---|
| Fresh / Failed / Ready | `play()` | Playing | `ListeningSession.swift:54-85` |
| Playing | `.finished` | Ready | `:73-75` |
| Playing | `.cancelled` (stop, scene inactive, interruption, route change) | Fresh | `:76-78` |
| Playing | `.failed` | Failed | `:79-82` |
| Ready | `answer` | Feedback, records 1 result | `:87-99` |
| Feedback | `play()` | Feedback, replaying | `:60-66` |
| Feedback, replaying | any outcome | Feedback | `:61-64` |
| Feedback | `next()` | Playing, new question | `:101-109` |
| any | `leave()` | player stopped; Playing → Fresh through the cancel callback | `:125-128` |

Rejected events: `play` while playing (`:55`), `answer` outside Ready or twice (`:88`),
`autoplayIfFresh` unless Fresh (`:112`).

Findings:
- **B1. Hear again failing gives no message.** The Feedback branch ignores the outcome
  (`:61-64`) and `FeedbackView` has no error state. A failed audio session start, or the
  watchdog giving up, leaves the speaker button disabled for up to about 2 × (0.93 s + 1.5 s),
  then it silently re-enables. Reachable through `TonePlayer.swift:91-93, 104-107, 127-128`.
- **D1. A cancelled Replay locks the answers again.** Same as Morse: wrist down during a
  Replay sends the learner back to "Play" although they already heard the note in full.
- G1. Parallel flags instead of one `Phase` enum (same as Morse G1).

After the fixes: `phase` is the only stored state:
`awaitingPlayback(error)`, `playing(replay)`, `awaitingAnswer(error)`,
`feedback(chosen, replaying, error)`. `isPlaying`, `playbackError`, `hasHeardQuestion` and
`canAnswer` are computed from it. D1 was decided as "keep the answers open": a cancelled replay
returns to `awaitingAnswer`, and a failed replay returns there with the error (red Retry, answers
still open). B1: a failed Hear again turns the speaker button red with a warning icon.

## 2. Audio engine: `TonePlayer` (implicit)

Same states, invariants and transitions as Morse §3:

| State | session | engine | isPlaying | completion | watchdog |
|---|---|---|---|---|---|
| Cold | inactive | stopped | false | nil | nil |
| Warm idle | active | running | false | nil | nil |
| Playing | active | running | true | set | armed (isRetry false) |
| Retrying | active | restarted | true | set | armed (isRetry true) |
| Route-changed | active | stopped | false | nil | nil |

Exactly-once outcome per `play`: finish `:162-170`, cancel `:149-160`, synchronous failure
`:91-93, :104-107`, watchdog failure `:127-128`, and the retry hand-off `:130-132`. A
`generation` bump on every play/cancel drops late buffer callbacks (`:163`).

Findings:
- **G2. No tests for the player.** `ListeningSessionTests` uses a fake; the watchdog, retry
  and generation logic are untested.
- **G3. Re-entrancy is unguarded.** The old completion runs inside `play` (`:86` → `:159`)
  before the new one is stored (`:89`). No completion starts a sound today, so it can't be
  reached.

After the fixes: the generation/completion bookkeeping and the watchdog decision live in
`PlaybackTracker` (no AVFoundation), tested by `PlaybackTrackerTests`. `begin` delivers the old
owner's `.cancelled` before storing the new completion; if that callback starts a newer sound, the
newer one wins and the interrupted `begin` reports `.cancelled` to its own caller.

Added 2026-11-15 (AirPods): a **Warming** state. On an engine configuration change (output
switched), while a practice screen holds the session (`sessionActive`), the player restarts the
engine (3 tries, 0.5 s apart) and plays 0.3 s of silence so the Bluetooth link is awake before
the next tap. Any `play`/`stop` cancels it (`warmUpItem`, `nodeBusy`). A play whose engine start
fails also retries 3 × 0.5 s before reporting `.failed`. The watchdog now waits
duration + output latency + 1.5 s, plus 2.5 s on headphones (`PlaybackTiming`), so a slow
Bluetooth start is no longer mistaken for a stall and replayed. `output` (speaker/headphones)
drives a headphones badge on the volume circle.

## 3. Who owns the shared player

Users: `ListeningSession`, `InstrumentView` preview (`SettingsView.swift:238-240`), and
the scene-phase handler (`DoremiTeacherApp.swift:20-26`). Navigation is Home → one screen
(Listening), or Home → Settings → Instrument (→ Reference picker). The two users can't be on
screen together, and each stops the player when it disappears (`ListeningView.swift:42`,
`SettingsView.swift:221`). Pushing the Reference picker from Instrument fires Instrument's
`onDisappear`, which stops a preview. That's harmless. No conflict is reachable.

## 4. Naming settings: `SettingsStore` + pickers (implicit)

Fields: `naming.style` (syllables | letters), `naming.relationship`
(standard | instrument(reference, soundsLike)), `noteSet`.

| State | style | relationship | Rows shown |
|---|---|---|---|
| Syllables, standard | syllables | standard | Note names, Names follow, Notes |
| Syllables, my instrument | syllables | instrument(r, p) | + My instrument |
| Letters | letters | standard (forced) | Note names, Notes |

Invariant: `style == .letters ⇒ relationship == .standard`. It's enforced by `normalize()` in
`didSet` (`PracticeSettings.swift:17-21, 28-38`). The nested assignment does re-run `didSet`
on a `@Published` property, so the normalized value is what gets saved. Verified, and covered by
`SettingsStoreTests.swift:35-37`.

| From | Event | To | Code |
|---|---|---|---|
| Syllables, standard | Names follow → My instrument | My instrument (Re → E) | `SettingsView.swift:123-127` |
| My instrument | Names follow → Standard | Syllables, standard | `:120-122` |
| My instrument | step ‹ › / Reference name | My instrument (r′, p′) | `:193, :226-227` |
| Syllables (either) | Note names → A B C | Letters | `:11-13` + normalize |
| Letters | Note names → Do Re Mi | Syllables, standard | `:11-13` |

Findings:
- **B2. The learner's instrument mapping is thrown away.** `NamesFollowPicker`'s doc comment
  says "Choosing My instrument keeps the last reference" (`SettingsView.swift:111-112`). But
  `.standard` carries no payload and nothing else remembers the mapping, so two reachable paths
  reset it to the default Re → E:
  1. My instrument (e.g. Re → D) → Names follow: Standard → Names follow: My instrument gives Re → E.
  2. My instrument → Note names: A B C (normalize drops it) → Note names: Do Re Mi → My
     instrument gives Re → E.

  Impact: saz and transposing-instrument players set this once. A casual look at A B C names
  silently loses it, and the next round is named wrongly for their instrument until they notice.
  This is the app's headline feature.

After the fix: `PracticeSettings.lastInstrument` (optional, so 1.0 settings still decode) is
updated by `normalize()` whenever the relationship is an instrument mapping, before letters force
it back to standard. Names follow → My instrument calls `useInstrumentNaming()`, which restores it
(or the saz example the first time). Settings loaded from disk are normalized too.

## 5. Scoring guard, day rollover, timers

Same as Morse §5–§7: a session-level `recordedQuestionID`, plus store-level
`StatsStore.lastRecordedQuestionID` (`StatsStore.swift:53, 95`); rollover by `dayKey` in
`refreshDay` (`:85-91`), called from init, `record`, scene `.active` and the Stats midnight timer
(`StatsView.swift:29-49`); the `VolumeView` focus timer (`VolumeView.swift:17-28`). No findings.

## 6. Debug navigation

`HomeView.demo` drives hidden links (`HomeView.swift:38-62`). DEBUG only.

## Notes outside the state machines

- G4. Throwaway sessions: `HomeView` observes the player, settings and stats, so every tone
  start/stop rebuilds `ListeningView.init`, which constructs a discarded session. Efficiency only.

## Issues (all fixed 2026-11-15)

| # | Issue | Findings | Impact | Size |
|---|---|---|---|---|
| 1 | Remember the instrument mapping across Standard and A B C | B2 | Medium: silent loss of the core setting | S: an *optional* `lastInstrument` field in `PracticeSettings` (synthesized Codable ignores default values, so a non-optional field would fail to decode 1.x settings and reset them) + SettingsStore tests for both paths and for decoding old data |
| 2 | Show a playback failure on the feedback screen | B1 | Low | S + test |
| 3 | Player decision function + tests | G2, G3 | Regression safety | M, shareable with Morse |
| 4 | One `Phase` enum for the round | G1, D1 | Readability | M |
| 5 | Lazy sessions in the NavigationLink destination | G4 | Efficiency | S |
