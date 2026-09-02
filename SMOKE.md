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
- [ ] `Settings…` and ⌘, open the settings window in front of other windows.
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
      could not be written and states plainly that the Dock was not changed.
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
- [ ] Right-click offers Apply (disabled when already applied), Rename… and a red
      Delete….
- [ ] Renaming to an existing name keeps the field open and says why; Esc cancels.
- [ ] A long name truncates with an ellipsis and the row does not grow.
- [ ] Deleting the active layout clears the `ACTIVE` badge.
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

- [ ] Delete asks for confirmation, the button is red and fires on Return.
- [ ] Esc cancels a deletion.
- [ ] A Dock with a separator produces the separator alert, not the "format
      changed" one. Set it up with `defaults write com.apple.dock persistent-apps
      -array-add '{"tile-type"="small-spacer-tile";}'` then `killall Dock`, and
      try to save a layout. Applying a layout does not clear it either — every
      apply starts by reading the Dock — so remove it with
      `defaults delete com.apple.dock persistent-apps` followed by `killall Dock`,
      which leaves an empty Dock, and then apply a saved layout.
A failed Dock restart is no longer reachable by hand: the only surviving trigger
is a running Dock that refuses to quit, which cannot be arranged from Terminal.
An absent Dock is not a failure — launchd starts one and it reads the domain
that was just written. Unit tests cover both.
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
