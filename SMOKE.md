# Manual smoke checklist

Applying a preset restarts the Dock, so none of this can run in CI.
Run it on a real macOS 26 machine after any change to DockEngine,
DockWriter or DockRestarter.

Before you start: `swift run shitsurae-cli backup`, and check that
`~/Library/Application Support/Shitsurae/backup/com.apple.dock.original.plist`
exists. Everything below is recoverable from that file:
`defaults import com.apple.dock <that file>` followed by `killall Dock`.

1. **Read** — `swift run shitsurae-cli dump` lists every app currently in your
   Dock, in the same order, with correct labels. Apps with spaces or
   non-Latin characters in their path show a readable path.
2. **Dry run** — save the dump as JSON, drop one app, then
   `swift run shitsurae-cli apply state.json --dry-run`. The output reflects the
   change and the real Dock does not move.
3. **Apply** — run the same command without `--dry-run`. The Dock blinks once
   and comes back with the app removed.
4. **Menu bar apps survive** — an app with `LSUIElement=true` that was in the
   Dock (for example `Apps`) is still there after applying.
5. **Settings** — change `tilesize` in the JSON, apply, and confirm the icons
   change size. Confirm keys that were absent from your domain are still absent
   afterwards: `defaults read com.apple.dock orientation` should still error.
6. **Backup is never overwritten** — run `backup` again, confirm it reports
   `already exists` and the file's modification date has not changed.
7. **Restore** — run the two restore commands from the top of this file and
   confirm the Dock returns to its original state.
