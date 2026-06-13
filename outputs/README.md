# Floatune

Floatune is a native macOS menu-bar controller for the Spotify desktop app. It provides a compact, always-on-top Liquid Glass player without requiring a separate Spotify login.

> Screenshot: Compact floating player

> Screenshot: Expanded floating player

> Screenshot: Menu-bar controls and settings

## Features

- Native macOS 26 Liquid Glass interface
- Compact and expanded floating-player layouts
- Song, artist, album, artwork, progress, and duration display
- Play, pause, previous, and next controls
- Seek, volume, shuffle, and repeat controls
- Responsive volume updates with Spotify synchronization
- Configurable global keyboard shortcuts
- Menu-bar controls with a show/hide player button
- Always-on-top and launch-at-login options
- Position restoration across launches
- Support for multiple Spaces and full-screen apps
- Adaptive light and dark appearance

## Requirements

- macOS 26 or newer
- Spotify for macOS
- Apple silicon Mac for the included unsigned build

Floatune controls the locally installed Spotify app through macOS Automation. Spotify Web API credentials and OAuth are not required.

## Installation

1. Open `Floatune.app`.
2. Allow Floatune to control Spotify when macOS asks for Automation permission.
3. Use the waveform icon in the menu bar to access controls and settings.

Floatune is a menu-bar utility and does not appear in the Dock.

If Automation access was denied, enable it in:

`System Settings > Privacy & Security > Automation`

## Floating Player

- Drag the window using the album artwork or song and artist area.
- Use the chevron button to expand or collapse the player.
- Use the close button to hide the floating window without quitting Floatune.
- Reopen it from the menu bar or the global show/hide shortcut.
- Sliders and playback controls remain interactive and do not move the window.

The expanded player includes progress seeking, volume, shuffle, repeat, and an Open Spotify button.

## Default Shortcuts

| Action | Shortcut |
| --- | --- |
| Show or hide player | `Control-Option-Space` |
| Play or pause | `Control-Option-P` |
| Previous track | `Control-Option-Left Arrow` |
| Next track | `Control-Option-Right Arrow` |

Shortcuts for all actions, including shuffle and repeat, can be recorded or cleared in Floatune Settings.

## Build From Source

Open `Floatune.xcodeproj` in Xcode 26.5 or newer, or run:

```sh
xcodebuild \
  -project Floatune.xcodeproj \
  -scheme Floatune \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build CODE_SIGNING_ALLOWED=NO
```

Run the tests with:

```sh
xcodebuild \
  -project Floatune.xcodeproj \
  -scheme Floatune \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  test CODE_SIGNING_ALLOWED=NO
```

## Troubleshooting

### Floatune cannot control Spotify

Confirm Spotify is installed and running, then enable Floatune under:

`System Settings > Privacy & Security > Automation`

### A shortcut does not register

The shortcut may already be reserved by macOS or another application. Record a different combination in Floatune Settings.

### The floating player is hidden

Open the Floatune menu-bar icon and select **Show Floating Player**, or press `Control-Option-Space`.

## Distribution

The included app is unsigned. macOS may require confirmation before opening it. Signing and notarization require an Apple Developer team.
