# Working in this repository

## Commands

```bash
swift test --package-path ShitsuraeCore     # the whole logic suite
swiftformat --lint .                        # must be clean before committing
xcodegen generate                           # after adding or moving a file
xcodebuild -project Shitsurae.xcodeproj -scheme Shitsurae -configuration Debug build
```

`Shitsurae.xcodeproj` is generated and git-ignored. Adding a source file means
regenerating it; `project.yml` is the source of truth.

## Layering

`Shitsurae` (app) → `ShitsuraeKit` (layouts, services, `AppModel`) →
`ShitsuraeCore` (the Dock domain). The arrows never point the other way.
`ShitsuraeCore` must not learn what a layout is, and `ShitsuraeKit` must not
import SwiftUI.

## Conventions

- **Do not write comments.** Names and types carry the meaning, and a comment
  restating the code goes stale at the next edit. Tests included.
- The one exception is a reader who would otherwise delete or "simplify"
  something load-bearing and bring the bug back. Then say why it is
  load-bearing, in two or three lines: the `nil` clear in `DockWriter.set` and
  the `onKeyUp` append in `HotkeyService` are the shape of it.
  Never a paragraph, and never a comment about what the code does.
- Everything in the repository is in English: identifiers, comments, commit
  messages, CI step names.
- Tests are named as sentences describing the guarantee
  (`aRestartFailureDoesNotSetTheActiveMark`), not after the method under test.
- A test that cannot fail is worse than no test. When adding one for a bug, check
  it actually fails against the unfixed code before committing.
- Pin the guarantee, not the edit. A test written against the line you just
  changed passes by construction and catches nothing later: state the rule in the
  user's terms ("a failure that already changed the Dock must not deny it"), not
  in the implementation's ("importFailed maps to writtenButNotApplied").

## Before changing anything on the Dock path

`DockEngine.apply` writes the user's Dock, and every blocker found late in
review lived there. Two rules, both mechanically enforced by
`DockFailureContractTests`:

- **Every error thrown after the domain is touched must map to a reason whose
  title and message admit it.** `DockFailureContractTests` builds its table from
  the errors rather than beside them. The domain state lives on the error itself
  (`DomainState.swift`), so a new case fails to compile in the sources until
  someone says whether the Dock has been written by then — before any test is
  even built. The table's sample list cannot be compiler-forced, because Swift
  cannot enumerate an enum with associated values; `theTableCoversEveryFailureOnTheDockPath`
  is the backstop for that half. A list that merely sits next to an exhaustive
  switch enforces neither, and fell two cases behind before this shape replaced it.
- **Redirecting an error to an existing reason means reading that reason's
  text.** The two are one edit, never two.

## What is deliberately left alone

- **`AppModel` is a facade over a genuinely coupled core, not a god object.**
  Every content edit has to run through `mutate`, which saves, replaces the
  layout in the list and clears the applied mark, so splitting the editor out
  would hand a new type the store, the marker and the list — most of the model's
  collaborators, for a thicker seam.
  Eight review passes attributed no defect to its size.
- **The app target has no tests.** The logic that can be tested lives in the
  package; what remains in the views is layout and wiring. `TileDrag` and
  `LayoutNote` exist because the arithmetic and the wording belong where they
  can fail a test.
- **`ShitsuraeCore` imports AppKit, for `NSRunningApplication` in `DockRestarter`.** It is the
  only one-call API that asks the Dock to quit politely; Foundation's route to the same quit
  event is a hand-built `NSAppleEventDescriptor`. The package is macOS-only, and the link costs
  the CLI about 1.5 ms at launch. Injecting the process source would move three lines into Kit
  and the CLI, and the CLI would still link AppKit to supply them.
- **`DockEngine.applyIfNeeded` reads the domain twice.** The second read is `preview`'s own
  readability check, pinned by `previewFailsOnAnUnreadableDomain`; seeding the sandbox from raw
  values without it would turn a wrong-typed key into a clean preview. A warm read of the seven
  keys costs 0.005 ms. A second `preview` entry point on the Dock path is not worth that.

## Invariants worth knowing

- **`ShitsuraeFailure` has five cases, and exactly one of them —
  `writtenButNotApplied` — means the Dock has already changed.** Every other
  message promises the user that nothing was touched, so every error thrown
  after a write has to map to that one case. Pinned by
  `onlyWrittenButNotAppliedAdmitsTheDockChanged` and
  `everyReasonThrownAfterTheDomainIsWrittenAdmitsIt`.
- **The user's way back is `Dock 1`, not a backup.** The seed captures the
  untouched Dock at first launch, and applying it restores every key the app can
  write, because a layout stores all seven and `nil` clears rather than skips.
  Pinned by `applyingASavedStateAgainPutsBackEverySettingTheAppCanChange`.
- **A layout is shown from one file, and that file is the one `save` and
  `delete` address.** `<id>.json` wins over any other file holding the same id,
  so an edit is never shadowed by a stale copy; the losers are reported as
  duplicates and never deleted, except by Delete, which removes every file
  holding that layout, address last. A file under another name is renamed into
  place by `adoptStrayFiles()` at launch and on `refreshFromDisk()`. Pinned by
  `anEditIsNeverShadowedByAStaleCopyOfTheSameLayout` and
  `aSkippedDuplicateFileIsNamedNotHidden`.
- **A tile's identity is its path, not its bundle identifier.** Two applications
  may carry one identifier — Xcode and Xcode-beta, or two copies of Chrome — and
  the Dock holds both side by side. `DockLayout.withUniqueApps`,
  `AppModel.addApps` and the strip all key on `DockApp.id`, which is the path.
  Keying on the bundle id silently dropped the second tile. Pinned by
  `savingADockThatHoldsXcodeAndXcodeBetaKeepsBothTiles`.
- **The write and the restart are one step, in that order.** The Dock reads
  `persistent-apps` at launch and holds the tile list in memory, then writes it
  back enriched with its own `GUID` and bookmark data — which is why tiles in the
  domain carry keys `DockWriter` never emits. A write with no restart is not
  merely invisible: the running Dock overwrites it from memory, so the layout is
  lost rather than delayed. Nothing may be inserted between the write and
  `restarter.restart()` in `DockEngine.apply`.
- **A layout that cannot be written to disk is not a Dock failure.** It raises
  `ShitsuraeAlertKind.saveFailed`, whose text promises the Dock is untouched —
  which it is, because nothing reached `DockEngine`.
- **Auto-Quit is a field of the layout, not Dock content.** `setQuitsOtherApps`
  saves the layout without going through `mutate`, so toggling it leaves the
  active mark alone: the Dock still holds that layout. Pinned by
  `turningAutoQuitOnKeepsTheActiveLayoutActive`.
- **The settings window shows what `AppModel.page` says, and nothing else.**
  `.layout(id)` or `.general`, `nil` for neither; `selectedLayout` is derived
  from it. Saving moves the page, applying moves it only when a layout page is
  already shown, because applying is reachable from a global hotkey and an
  action outside the window must not move the window. Pinned by
  `savingWhileGeneralIsShownShowsTheNewLayout`,
  `applyingWhileGeneralIsShownLeavesGeneralAlone` and
  `applyingWhileALayoutIsShownShowsTheAppliedOne`.
- **One alert is on screen at a time, and the model decides which.** `alerts`
  is a queue, `alert` is its head, and `beginPresenting()` hands the head to
  one caller and `nil` to everyone after it until an answer arrives. An answer
  names the kind it was given for and is ignored if that is not the head, so a
  question is never answered by a click meant for something else, and a
  `writtenButNotApplied` raised under an open question waits rather than
  replacing it. `AlertPresenter` keeps no state of its own: it asks, shows and
  reports back. Pinned by `onlyOneCallerIsToldToShowAnAlert`,
  `answeringHandsTheNextAlertToTheNextCaller` and
  `anAnswerMeantForAnotherDialogIsIgnored`.
- **State kept outside the model is invisible to SwiftUI.** `activeLayoutID` is
  a stored property written only by `setActiveLayout`, which writes through to
  the one `ActiveLayoutMarker` the model owns. Turning it into a computed
  property over `UserDefaults` silently breaks every view that reads it.
- **`reload()` is the only path that fills `layouts` from the folder, and no edit
  calls it.** An edit updates the list from the value it wrote, so a folder that
  cannot be listed never hides a save that succeeded. It runs at launch and,
  through `refreshFromDisk()`, whenever the settings window becomes key. Pinned
  by `aRenameThatReachedTheDiskIsShownEvenWhenTheFolderCannotBeListed` and
  `anEditTheStoreRefusedIsNotShownAndThenTakenBack`.
- **The app icon must be full-bleed and resized with `sips`.** macOS 26 treats a
  PNG drawn through our own `NSBitmapImageRep` as a legacy icon and puts a light
  plate behind it in the Dock. See `Design/make-appicon.swift`.

## Verifying UI work

SwiftUI layout claims are cheap to measure and expensive to guess. Host the view
in an `NSHostingView`, read `intrinsicContentSize`, or render it with
`cacheDisplay(in:to:)` and look at the PNG. Measuring settles questions like "is
this text clipped" and "does this row change height" in seconds.
