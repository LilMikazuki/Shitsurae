# Shitsurae

A macOS app that saves your Dock as named layouts and switches between them from
the menu bar, from the settings window, or with a global hotkey. It lives in the
menu bar, and also takes a Dock tile and a ⌘Tab slot so its settings window
behaves like any other app's.

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
- **Restore your original Dock.** The first time a layout is applied, Shitsurae
  backs up the untouched Dock domain and keeps that backup for good.

Shitsurae never writes to the Dock without a backup it can restore, and it tells
you plainly whether a failure left your Dock alone or already changed it.

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
| `ShitsuraeCore/Sources/ShitsuraeCore/` | Reading and writing `com.apple.dock`, the backup, restarting the Dock. Knows nothing about layouts. |
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
  so they can be copied between machines.
- The Dock backup: `~/Library/Application Support/Shitsurae/backup`.
- Hotkeys: in the app's preferences domain, not in the layout files — a layout
  copied to another machine deliberately brings no shortcuts with it.

## The CLI

`shitsurae-cli` exercises the core package without the app:

```
Usage: shitsurae-cli <command>

Commands:
  dump [--json]            Print the current Dock layout and settings;
                           --json prints a DockState JSON document instead
  backup                   Create the one-time backup of the Dock domain
  apply <file> [--dry-run] Apply a DockState JSON file; --dry-run prints the
                           result without touching the real Dock
  restore                  Restore the Dock domain from the backup and
                           restart the Dock. Fails if no backup exists.
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
