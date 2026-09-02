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
  Every content edit has to run through `mutate`, which clears the applied mark
  and reloads, so splitting the editor out would hand a new type the store, the
  marker and the reload — most of the model's collaborators, for a thicker seam.
  Eight review passes attributed no defect to its size.
- **The app target has no tests.** The logic that can be tested lives in the
  package; what remains in the views is layout and wiring. `TileDrag` and
  `LayoutNote` exist because the arithmetic and the wording belong where they
  can fail a test.

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
- **A layout that cannot be written to disk is not a Dock failure.** It raises
  `ShitsuraeAlertKind.saveFailed`, whose text promises the Dock is untouched —
  which it is, because nothing reached `DockEngine`.
- **Auto-Quit is a field of the layout, not Dock content.** `setQuitsOtherApps`
  saves the layout without going through `mutate`, so toggling it leaves the
  active mark alone: the Dock still holds that layout. Pinned by
  `turningAutoQuitOnKeepsTheActiveLayoutActive`.
- **State kept outside the model is invisible to SwiftUI.** `activeLayoutID`
  lives in `UserDefaults`; `AppModel` mirrors it into a stored property and
  refreshes it in `syncServices()`. Turning it back into a computed property
  silently breaks every view that reads it.
- **The app icon must be full-bleed and resized with `sips`.** macOS 26 treats a
  PNG drawn through our own `NSBitmapImageRep` as a legacy icon and puts a light
  plate behind it in the Dock. See `Design/make-appicon.swift`.

## Verifying UI work

SwiftUI layout claims are cheap to measure and expensive to guess. Host the view
in an `NSHostingView`, read `intrinsicContentSize`, or render it with
`cacheDisplay(in:to:)` and look at the PNG. Measuring settles questions like "is
this text clipped" and "does this row change height" in seconds.
