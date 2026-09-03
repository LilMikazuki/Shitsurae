# Shitsurae

A macOS app that saves your Dock as named layouts and switches between them from
the menu bar, from the settings window, or with a global hotkey. It lives in the
menu bar alone: no Dock tile, no ⌘Tab slot. The settings window is opened from
the menu.

*Shitsurae* (しつらえ) is the Japanese practice of arranging a space for the
occasion at hand. Work, personal, screen sharing — each gets its own Dock.

## What it does

- **Save the current Dock** as a named layout: its apps, their order, and the
  Dock's own settings — position, tile size, magnification and its size,
  auto-hide, and whether recent applications are shown.
- **Switch layouts** from the menu bar, or bind a global hotkey to each one.
- **Optionally quit what you left behind.** With Auto-Quit on for a layout,
  applying it asks the applications outside it to quit — politely, so anything
  with unsaved work can still stop you.
- **Edit a layout in place** — drag tiles to reorder, drop an app from Finder to
  add it, remove one from the tile's context menu.
On first launch Shitsurae saves whatever is in your Dock as a layout called
`Dock 1`, so applying it later puts the Dock back the way you found it. It also
tells you plainly whether a failure left your Dock alone or already changed it.

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon
- Xcode 26 or later to build

## Building

```bash
brew install xcodegen swiftformat
xcodegen generate
xcodebuild -project Shitsurae.xcodeproj -scheme Shitsurae -configuration Debug build
```

The logic lives in a Swift package that builds and tests on its own:

```bash
swift test --package-path ShitsuraeCore
```

## Layout of the repository

| Path | What lives there |
| --- | --- |
| `Shitsurae/` | The app target: SwiftUI views, the menu bar scene, alert presentation. |
| `ShitsuraeCore/Sources/ShitsuraeCore/` | Reading and writing `com.apple.dock`, restarting the Dock. Knows nothing about layouts. |
| `ShitsuraeCore/Sources/ShitsuraeKit/` | Layout storage, services, `AppModel`. Platform-aware, UI-free. |
| `ShitsuraeCore/Sources/shitsurae-cli/` | A debugging CLI for the core. |
| `Design/` | The app icon and the script that builds it. |

The dependency direction is one-way: the app depends on the kit, the kit depends
on the core, and nothing depends on the app.

`ShitsuraeCore` is the part worth reusing on its own — it reads and writes the
Dock's preferences domain, backs it up and restarts the Dock, and knows nothing
about layouts. `ShitsuraeKit` exists for this app: it is a Swift package target
only because the app is a separate module, its public symbols are public for
that reason alone, and its shape will follow the app rather than any outside
consumer.

### Where your data lives

- Layouts: `~/Library/Application Support/Shitsurae/layouts`, one JSON file each,
  so they can be copied between machines. A file copied in under any name is
  picked up the next time the settings window is opened, or at the next launch,
  and renamed after the layout's id. A second file holding a layout that is
  already there is skipped and named in the settings sidebar rather than shown
  twice.
- Hotkeys: in the app's preferences domain, not in the layout files — a layout
  copied to another machine deliberately brings no shortcuts with it.

### Diagnosing a problem

Shitsurae logs what it does and every failure it meets to the unified log, under
the subsystem `io.github.lilmikazuki.Shitsurae`. To see the last hour:

```bash
log show --last 1h --predicate 'subsystem == "io.github.lilmikazuki.Shitsurae" AND process == "Shitsurae"'
```

or, to watch it live while reproducing something:

```bash
log stream --predicate 'subsystem == "io.github.lilmikazuki.Shitsurae" AND process == "Shitsurae"'
```

The `process` clause keeps the test suite out: `swift test` builds layout stores and
models that log through the same subsystem, and without it a run adds over a hundred
lines to what you are reading.

Layout names never appear there — a layout is identified by its id, which is also
its file name. Paths, bundle ids, Dock keys and error descriptions do, so the
output is safe to read but worth a glance before pasting it into an issue.

## The CLI

`shitsurae-cli` exercises the core package without the app:

```
Usage: shitsurae-cli <command>

Commands:
  dump [--json]            Print the current Dock layout and settings;
                           --json prints a DockState JSON document instead
  apply <file> [--dry-run] Apply a DockState JSON file; --dry-run prints the
                           result without touching the real Dock
```

## Known limits

- Dock separators (`spacer-tile` and friends) are a real Dock feature that
  Shitsurae does not round-trip yet. Reading a Dock that contains one fails with
  a message that names the tile rather than corrupting it.
- Folders and documents pinned to the right-hand side of the Dock are not part
  of a layout yet.
- The minimize effect and other Dock preferences outside the seven keys above
  are left exactly as they are; switching layouts never touches them.
- Editing the layout that is currently applied does not re-apply it. The Dock
  keeps what it had, and the layout stops being marked as applied until you
  press Apply again.

## Contributing

The bar for this codebase is that the code explains itself. Comments are rare
and short, and only where a reader would otherwise "fix" something load-bearing.
Everything else is carried by names, types, and tests.

Before opening a pull request:

```bash
swiftformat --lint .
swift test --package-path ShitsuraeCore
```

## License

MIT — see [LICENSE](LICENSE).
