# Fixtures

## `dock-macos-26.5.2.plist`

The `com.apple.dock` domain taken from a live machine: macOS 26.5.2 (build
25F84), MacBook Pro Mac14,10, Apple M2 Pro, captured 2026-08-30 with
`defaults export com.apple.dock`.

**Sanitised.** Only stock Apple applications were kept in `persistent-apps`; ten
third-party entries were removed. The remaining four are as they came, `book`
blobs included, with one edit: the boot volume's UUID inside each blob is replaced
by zeros of the same length, so the bookmark structure is untouched. Nothing else
was synthesised. All 20 top-level keys are present.

What this fixture exists to prove:

- `Apps` (`com.apple.apps.launcher`) — an application with `LSUIElement=true`
  sits in the Dock as an ordinary tile. `DockReader` and `DockWriter` must not
  lose it.
- `tilesize` arrives as a **float** (82.0), not an int.
- `magnification`, `largesize` and `orientation` are **absent** from the domain.
  That is normal: they are defaults, and a missing key is not a parse error.
- `tile-data` carries keys the model does not know: `book`, `dock-extra`,
  `file-type`, `file-mod-date`, `parent-mod-date`, `is-beta`, plus `GUID` at the
  element's top level. They exist in a live domain and are **deliberately not
  carried into the model**: `book` is a bookmark blob tied to one machine, and
  layouts must survive being copied to another. `DockWriter` therefore writes a
  minimal tile and lets the Dock fill in the rest on its next save. Their absence
  after a round-trip is correct behaviour, not a bug to "fix".

When macOS 27 ships, add its fixture alongside this one rather than replacing it.
