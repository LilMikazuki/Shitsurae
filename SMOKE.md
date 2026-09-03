# Manual smoke checklist

Applying a layout restarts the Dock, so none of this can run in CI. Run it on a
real macOS 26 machine after any change to `DockEngine`, `DockWriter` or
`DockRestarter`.

Run every `swift run` command below from the `ShitsuraeCore` directory, where the
package lives.

Before you start: `swift run shitsurae-cli dump --json > original.json`.
Everything below is recoverable — `swift run shitsurae-cli apply original.json`
puts the Dock back the way it was — and the app itself keeps a way back, because
the first launch saves your untouched Dock as the layout `Dock 1`.

## Core, through the CLI

1. **Read** — `swift run shitsurae-cli dump` lists every app currently in your
   Dock, in the same order, with correct labels. Apps with spaces or non-Latin
   characters in their path show a readable path. Save a copy for later:
   `swift run shitsurae-cli dump --json > original.json`.
2. **Dry run** — `swift run shitsurae-cli dump --json > state.json`, drop one app
   from the JSON, then `swift run shitsurae-cli apply state.json --dry-run`. The
   output reflects the change and the real Dock does not move.
3. **Apply** — run the same command without `--dry-run`. The Dock blinks once and
   comes back with the app removed.
4. **Menu bar apps survive** — an app with `LSUIElement=true` that was in the Dock
   is still there after applying.
5. **Settings** — change `tilesize` in the JSON, apply, and confirm the icons
   change size. Confirm keys that were absent from your domain are still absent
   afterwards: `defaults read com.apple.dock orientation` should still error.
6. **Apply rejects stray arguments** — `apply state.json --dryrun` fails with
   "Unrecognized argument(s)" and does **not** apply. `apply` rewrites the whole
   Dock, so a silently swallowed argument would be the most expensive one in the
   tool.

## The menu bar

- [ ] After launch the icon appears at the right of the menu bar.
- [ ] The app icon appears in the Dock and in the ⌘Tab switcher.
- [ ] `Quit Shitsurae` quits the app.
- [ ] `Settings…` opens the settings window in front of other windows, on the first click —
      try it several times from different frontmost apps, because the failure it replaces was
      intermittent rather than constant. It has no key equivalent: a shortcut on an item that
      lives only in the status-item menu fires but leaves the window behind, and the main-menu
      command that would carry one was not built. Clicking the item and clicking the Dock tile
      are the two ways in.
- [ ] With no windows open, clicking Shitsurae's tile in the Dock opens the settings window in
      front of other windows.
- [ ] With no layouts, the menu shows a hint that cannot be clicked.
- [ ] Clicking a layout restarts the Dock and moves the checkmark to it.
- [ ] Every row's title starts at the same left edge, checked or not.
- [ ] The menu width does not jump when the active layout changes.

## Auto-Quit

Auto-Quit lives on the layout screen and applies to every layout, not just the
one on screen. Turn it off again when you are done testing.

- [ ] With it on, applying a layout asks the applications outside that layout to
      quit, and leaves Finder and Shitsurae alone.
- [ ] An application with unsaved work can still refuse, and nothing else breaks.
- [ ] A failed apply quits nothing.
- [ ] The setting survives quitting and relaunching the app.

## Launch at login

- [ ] Enabling it makes the app appear in System Settings → General → Login Items.
- [ ] After a reboot the app comes back on its own and sits in the menu bar.
- [ ] Disabling it removes the entry.
- [ ] The checkbox matches the system state when the screen opens, even if the
      entry was removed by hand.
- [ ] If macOS refuses the change, a red line explains why and the checkbox does
      not silently bounce back without a word.

## The save dialog

- [ ] Opens in front of other windows with focus already in the name field.
- [ ] The default name is `Layout N`, where N is one more than the layout count.
- [ ] Return saves, Esc closes without saving.
- [ ] An empty name disables Save and shows no error text.
- [ ] A duplicate name shows an error, outlines the field in red and disables
      Save; neither case nor surrounding spaces get around it.
- [ ] When the Dock cannot be read, Save explains why instead of doing nothing,
      and the explanation does not reappear over the next successful action.
- [ ] With the layouts directory itself made read-only — `chmod u-w
      ~/Library/Application\ Support/Shitsurae/layouts` — Save says the layout
      could not be written, states plainly that the Dock was not changed, and names
      the very directory you just made read-only — not its parent.
      Undo with `chmod u+w` on the same directory. Making the *parent* read-only
      does nothing: the write lands one level deeper.

## The settings window

- [ ] ⌘, opens it in front of other windows; closing it does not quit the app.
- [ ] The window can be resized and does not clip its contents at the minimum.
- [ ] The gear in the sidebar footer opens General and shows a filled background
      while it is open; selecting a layout returns to the layout screen.

## The layout list

- [ ] Exactly one row is highlighted, and the highlight is the system's — no
      second bar bleeding around it.
- [ ] The `ACTIVE` badge sits on the applied layout and stays readable on both a
      selected and an unselected row.
- [ ] Arrow keys move the selection; Return starts renaming.
- [ ] Right-click offers Apply (disabled when already applied), Rename and a red
      Delete. Rename opens the editing field — a menu item that is enabled and does
      nothing is what this catches; Return on a selected row opens it too.
- [ ] Renaming to an existing name keeps the field open and says why; Esc cancels.
- [ ] A long name truncates with an ellipsis and the row does not grow.
- [ ] Deleting the active layout clears the `ACTIVE` badge.
- [ ] A layout file copied into `~/Library/Application Support/Shitsurae/layouts` under another
      name appears after the settings window is opened, without a relaunch, and can then be
      renamed and deleted like any other.
- [ ] A Finder duplicate of a layout file shows one row plus an orange line saying one file
      duplicates another layout, whose tooltip names the file.
- [ ] Deleting a layout that has a duplicate file removes both: the layout does not come back
      after a relaunch.
- [ ] On a machine with no layouts, launch the app and confirm `Dock 1` appears
      and is marked active. Apply a different layout, then apply `Dock 1`: the
      Dock returns to what it was, including settings that were absent before.

## The layout screen

- [ ] The name, the last-used line and the Apply pill are centred as one block.
- [ ] Apply is disabled and reads "Applied" for the layout already in the Dock.
- [ ] Pressing Apply restarts the Dock and the pill becomes "Applied" without
      any other interaction.
- [ ] The card keeps its height when the hotkey hint appears and disappears.
- [ ] Switching between a layout with a missing app and one without moves nothing
      vertically.

## The Dock strip

- [ ] Icons are drawn as themselves: no box or rounded-square crop around them.
- [ ] Dragging a tile reorders it, and the neighbours move aside while dragging.
- [ ] Move Left / Move Right in the context menu do the same thing, and are
      disabled at the ends.
- [ ] Remove from Layout removes exactly that tile.
- [ ] The `+` tile opens the open panel; choosing several applications adds them
      all at once.
- [ ] Dropping an application from Finder adds it; dropping a non-application, or
      an app already in the layout, explains itself in the line below the strip.
- [ ] A missing application is dimmed with a dashed border and named in the note.
- [ ] With more apps than fit, the strip scrolls; the edge with more content
      behind it fades, and the edge you have reached does not.
- [ ] Applying a layout whose app was deleted from disk leaves that tile out of
      the Dock rather than putting a question mark there.
- [ ] Two applications that share a bundle identifier — `Google Chrome.app` and
      `Google Chrome 2.app` on this machine, Xcode and Xcode-beta in general — can both be added
      to one layout, both tiles drag independently, and saving a Dock that holds both keeps both.

## Hotkeys

- [ ] Clicking the pill starts recording and the row shows what to press.
- [ ] The shortcut is saved when all keys are released, not on the first key.
- [ ] A combination without ⌘ or ⌥ is refused with an explanation.
- [ ] A combination already used by another layout names that layout in red and
      does not overwrite anything.
- [ ] ⌫ clears the shortcut, Esc cancels without changing it.
- [ ] Right-clicking the pill offers Clear Shortcut, disabled when none is set.
- [ ] The global shortcut applies its layout from another application.
- [ ] While recording, pressing a combination already bound to another layout
      shows the conflict instead of applying that layout.
- [ ] Applying twice in quick succession — hotkey plus a click — restarts the
      Dock once, not twice.
- [ ] Closing the window mid-recording ends the recording; reopening shows the
      pill back at rest.

## Alerts

- [ ] An alert never stacks on another, and the one that says the Dock changed is not lost.
      Freeze the Dock with `kill -STOP $(pgrep -x Dock)`. Open Settings, right-click a layout →
      Delete… so the question is on screen, then press the hotkey of a different layout. The apply
      gives up after about five seconds: the question stays on top and nothing appears over it.
      Press the same hotkey again — a press during those five seconds is dropped by
      `isChangingDock`, so wait for the first to end — and again nothing appears over the question.
      Press Cancel: "Your Dock was changed but not applied" appears exactly once, and the layout is
      still in the list. Thaw with `kill -CONT $(pgrep -x Dock)`; the Dock relaunches holding what
      the failed applies wrote, so apply the layout you started from.
- [ ] Delete asks for confirmation, the button is red and fires on Return.
- [ ] A layout that cannot be deleted: `chmod u-w ~/Library/Application\ Support/Shitsurae/layouts`,
      Delete a layout, confirm. The alert says the layout is still in the list, that the Dock was
      not changed, and names the very directory you just made read-only; the row stays, and the
      `ACTIVE` badge stays if it had it. Undo with `chmod u+w` on the same directory.
- [ ] Esc cancels a deletion.
- [ ] A Dock with a separator produces the separator alert, not the "format
      changed" one. Set it up with `defaults write com.apple.dock persistent-apps
      -array-add '{"tile-type"="small-spacer-tile";}'` then `killall Dock`, and
      try to save a layout. Applying a layout does not clear it either — every
      apply starts by reading the Dock — so remove it with
      `defaults delete com.apple.dock persistent-apps` followed by `killall Dock`,
      which leaves an empty Dock, and then apply a saved layout.
- [ ] `writtenButNotApplied` — freeze the Dock with `kill -STOP $(pgrep -x Dock)`, then apply a
      different layout from the menu. The menu's layout rows stay disabled while Shitsurae waits;
      after about five seconds expect "Your Dock was changed but not applied" with the
      `killall Dock` advice, the `ACTIVE` badge does not move and the pill does not read
      "Applied". Thaw with `kill -CONT $(pgrep -x Dock)`: the Dock processes the queued quit,
      comes back and shows the new layout. Press Apply again — the layout is not marked active,
      so this is a real apply: the Dock blinks and the pill turns "Applied".
- [ ] The same refusal through the CLI, which runs no run loop: freeze the Dock the same way, then
      `swift run shitsurae-cli apply state.json` with the file from Core step 2. After about five
      seconds it exits non-zero with "The Dock layout was written, but the Dock did not restart:
      The Dock was asked to quit but is still running." followed by the `killall Dock` line. Thaw
      with `kill -CONT $(pgrep -x Dock)`; the Dock comes back holding the applied state. This is
      the half of the proof that the liveness check works without a run loop; the Core apply steps
      are the other half.

An absent Dock is still not a failure. Note what brings it back: `com.apple.Dock.plist` sets
`KeepAlive` to `SuccessfulExit: false`, and a polite quit is a successful exit, so the Dock
returns on a demand for one of its Mach services rather than because launchd restarts it. Every
step above that quits the Dock should confirm it actually comes back.
- [ ] `unreadableLayout` — `defaults write com.apple.dock tilesize -string "big"`,
      `killall Dock`, then try to save a layout. Expect "can't read your Dock
      layout". Undo: `defaults delete com.apple.dock tilesize 2>/dev/null`, then
      `swift run shitsurae-cli apply original.json`.
- [ ] `unsupportedSetting` — `defaults write com.apple.dock orientation -string
      "diagonal"` (right type, unknown value), then try to save a layout. Expect
      text naming both the key and the value: this is the only failure a user can
      fix themselves, so the substitution has to be visible. Undo the same way as
      above.

`writeFailed` cannot be reproduced by hand either: there is no reliable way to
make the preferences daemon reject a write. Covered by the failure-mapping unit
test.

## Console

Run this in a Terminal for the whole session below. `--level debug` so nothing is hidden: the
shortcut-registration count is the only `debug` line, and `--level info` would hide it.

```bash
log stream --predicate 'subsystem == "io.github.lilmikazuki.Shitsurae" AND process == "Shitsurae"' --level debug
```

This section is the only check that the live logger reaches the unified log at all. No test can
see it: the recording fake is handed each message before `os.Logger` is.

- [ ] Applying a layout writes one `dock` notice naming the layout id and the tile count, and says
      whether the Dock was written or already held it.
- [ ] Pressing a hotkey writes a `hotkeys` notice with the layout id before the apply line. The
      `hotkeys` debug count appears too — `register` runs on every reload — which is how you can
      tell `--level debug` took.
- [ ] The `unsupportedSetting` scenario under Alerts writes a `dock` error whose reason is
      `unsupportedSetting` and whose error names both the key and the value. One line, from
      `saveCurrentDock`'s read catch — not one per throw.
- [ ] With the Dock frozen, the failed apply writes one `dock` error naming `writtenButNotApplied`
      and no "Applied layout" notice.
- [ ] The refused delete above writes a `layouts` error with the layout id.
- [ ] On a machine with no layouts, the first launch writes a `layouts` notice carrying the id of
      the seeded layout and not its name; quit and launch again and no second seed line appears.
- [ ] Copying a layout file in under a name of your own and then opening the settings window writes
      a `layouts` notice naming both the file you copied and the address it now has.
- [ ] No line in the whole session contains a layout name: name a layout `Canary`, apply, rename
      and delete it, and `grep Canary` the stream. Empty.
- [ ] No line in the whole session reads `<private>`. That would mean `SystemEventLog.record` lost
      its `privacy: .public`, which hides every line rather than leaking one and leaves a bug
      report with nothing in it.

## Appearance and accessibility

Four combinations: light and dark × Reduce Transparency off and on, plus
Increase Contrast. Where to turn them on:

- light / dark — System Settings → Appearance;
- Reduce Transparency — Accessibility → Display → Reduce transparency;
- Increase Contrast — Accessibility → Display → Increase contrast.

- [ ] The menu is readable in all of them, both with layouts and empty.
- [ ] The save dialog, including the red error line, is readable in all of them.
- [ ] The sidebar: selected row, `ACTIVE` badge, footer.
- [ ] The layout screen: the controls card is distinct from the window behind it,
      and the dashed border of a missing app is visible.
- [ ] General: the Launch at login caption and the storage line at the bottom.
- [ ] All three alerts, including the red Delete button.
- [ ] With Increase Contrast the borders are solid and secondary text is stronger.

## Keyboard

- [ ] Esc closes one layer at a time: alert, dialog, settings, menu.
- [ ] Return fires the default button in the dialog and in alerts.
- [ ] Tab reaches every control in the settings window.
- [ ] VoiceOver announces the Auto-Quit switch as a switch with its label, and
      reads a Dock tile's app name and whether it is missing.

## Large system text

The mockups are fixed-size and do not cover this. The requirement is minimal: the
interface must not break.

- [ ] With Accessibility → Display → Text → a large size, the settings window does
      not clip the captions under the checkbox or the icon-name-version-license
      block at the bottom of General.
- [ ] Sidebar rows do not overlap.
- [ ] The layout screen does not push the Dock strip off the edges.
