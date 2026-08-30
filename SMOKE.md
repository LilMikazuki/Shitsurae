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
   non-Latin characters in their path show a readable path. Save a copy for
   later: `swift run shitsurae-cli dump --json > original.json`.
2. **Dry run** — `swift run shitsurae-cli dump --json > state.json`, drop one
   app from the JSON, then
   `swift run shitsurae-cli apply state.json --dry-run`. The output reflects
   the change and the real Dock does not move.
3. **Apply** — run the same command without `--dry-run`. The Dock blinks once
   and comes back with the app removed.
4. **Menu bar apps survive** — an app with `LSUIElement=true` that was in the
   Dock (for example `Apps`) is still there after applying.
5. **Settings** — change `tilesize` in the JSON, apply, and confirm the icons
   change size. Confirm keys that were absent from your domain are still absent
   afterwards: `defaults read com.apple.dock orientation` should still error.
6. **Backup is never overwritten** — note the file's modification date with
   `stat -f "%Sm" ~/Library/Application\ Support/Shitsurae/backup/com.apple.dock.original.plist`,
   run `backup` again, confirm it reports `already exists`, and re-run `stat`
   to confirm the date is unchanged.
7. **Restore** — run the two restore commands from the top of this file, then
   `swift run shitsurae-cli dump --json > restored.json` and
   `diff original.json restored.json` to confirm the Dock returned to its
   original state.

## Restoring the original Dock

7. **Restore refuses without a backup** — on a machine with no backup yet,
   `shitsurae-cli restore` fails with "There is no backup to restore from."
   and a non-zero exit code.
8. **Restore actually restores** — run `backup`, rearrange the Dock by hand,
   then `restore`. The Dock blinks once and comes back as it was.
9. **The backup survives restoring** — `ls` the backup file afterwards; it is
   still there, and `restore` can be run a second time.
10. **Restore rejects stray arguments** — `restore --dryrun` fails with
    "Unrecognized argument(s)" and does not restore.
