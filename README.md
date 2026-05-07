# Mobile Recorder

> A tool for screen recording, log capturing, and taking screenshots on Android and iOS devices — available as both a **CLI script** and a **native macOS menu bar app**.

## Overview

This project provides two ways to record your mobile device:

| | CLI (Shell Script) | macOS App (SwiftUI) |
|---|---|---|
| Interface | Terminal | Menu bar |
| Multi-device | One at a time | Simultaneous |
| Global hotkeys | — | `Cmd+Shift+R` / `Cmd+Shift+S` |
| Live log viewer | — | Built-in window |
| Notifications | — | Native macOS notifications |
| Requirements | macOS (zsh) | macOS 14.0+ |

## Features

| Feature | Android | iOS |
|---------|---------|-----|
| Screen recording + Log capture | ✅ | ✅ |
| Screenshot | ✅ | ✅ |
| Package-based log filtering | ✅ | — |

### Android Extras
- Enter a **package name** during recording to filter logs (only capture logs from that specific app)
- Supports log capture on Android versions below 7 (via `grep` filtering)

## Prerequisites

### Android Debug Bridge (adb)

adb is part of Android SDK Platform Tools, used to communicate with Android devices.

**Install via Homebrew (recommended):**

```bash
brew install --cask android-platform-tools
```

**Or download manually:**

1. Go to [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools) and download
2. Extract and add the path to your environment variables:

```bash
# Add to ~/.zshrc (adjust the path based on your actual extraction location)
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
```

**Verify installation:**

```bash
adb version
```

### iOS Development Bridge (idb)

idb is a tool developed by Facebook for interacting with iOS simulators and physical devices.

**Installation steps:**

```bash
# 1. Install idb-companion (via Homebrew)
brew tap facebook/fb
brew install idb-companion

# 2. Install idb client (via pip)
pip3 install fb-idb
```

> ⚠️ Requires [Python 3](https://www.python.org/downloads/) and [Homebrew](https://brew.sh/) to be installed first.

**Verify installation:**

```bash
idb list-targets
```

## Usage

### CLI (Shell Script)

#### Option 1: Run directly in terminal

```bash
# Grant execute permission (only needed once)
chmod +x Recorder.sh

# Run
./Recorder.sh
```

#### Option 2: Double-click the `.command` file

Double-click `Recorder.command` in Finder to automatically open Terminal and run the script.

> First-time use requires execute permission: `chmod +x Recorder.command`

**CLI Commands:**

| Command | Description |
|---------|-------------|
| `v`     | Screen recording + Log capture |
| `s`     | Screenshot |
| `r`     | Switch platform |
| `q`     | Quit |

### macOS App (MobileRecorder)

The macOS app lives in the menu bar and provides a graphical interface for all recording features.

**Build & Run:**

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you haven't already:
   ```bash
   brew install xcodegen
   ```
2. Generate the Xcode project and open it:
   ```bash
   cd MobileRecorder
   xcodegen generate
   open MobileRecorder.xcodeproj
   ```
3. Build and run from Xcode (requires macOS 14.0+).

**Global Hotkeys:**

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+R` | Toggle recording |
| `Cmd+Shift+S` | Take screenshot |

**Menu Bar Features:**
- Auto-detects connected Android/iOS devices
- Shows recording timer in the menu bar
- Start/stop recordings per device (multi-device supported)
- Live log viewer window
- Recent sessions list with quick access to output folders
- Tool availability indicators (adb / idb status)

## Workflow

```
CLI:
  1. Select platform → Android (1) / iOS (2)
  2. Detect device connection status
  3. Choose an action:
     ├── v: Screen recording (press any key to stop)
     ├── s: Screenshot
     ├── r: Switch platform
     └── q: Quit

App:
  1. Click menu bar icon
  2. Select a connected device
  3. Start Recording / Take Screenshot / Open Log Viewer
  4. Click to stop — files saved automatically
```

## Output Structure

Recordings, logs, and screenshots are saved in corresponding folders on the Desktop:

```
~/Desktop/
├── AndroidRecorder/
│   └── 20260303_143000/
│       ├── Screenrecord-20260303_143000.mp4
│       ├── Log-20260303_143000.log
│       └── Screenshot-20260303_143005.png
└── iOSRecorder/
    └── 20260303_143100/
        ├── Screenrecord-20260303_143100.mp4
        ├── Log-20260303_143100.log
        └── Screenshot-20260303_143105.png
```

## Project Structure

```
.
├── README.md
├── Recorder.command             # Double-click to run (macOS)
├── Recorder.sh                  # CLI main script
└── MobileRecorder/              # macOS menu bar app
    ├── project.yml              # XcodeGen project spec
    ├── MobileRecorder/
    │   ├── App/                 # App entry point & Info.plist
    │   ├── Models/              # Data models (Device, Platform, etc.)
    │   ├── ViewModels/          # AppState (core logic)
    │   ├── Views/               # SwiftUI views (MenuBar, Preferences, etc.)
    │   ├── Services/            # Android/iOS/Hotkey/Notification services
    │   └── Utilities/           # Constants, ToolLocator
    └── MobileRecorderTests/     # Unit tests
```

## System Requirements

- **CLI:** macOS (with zsh)
- **App:** macOS 14.0+ (Sonoma), Xcode 16+
- Android devices must have **USB Debugging** enabled
- iOS devices must be connected via USB and trusted by the computer
