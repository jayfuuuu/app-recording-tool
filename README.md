# Mobile Recorder

> A command-line tool for screen recording, log capturing, and taking screenshots on Android and iOS devices.

## Features

| Command | Description | Android | iOS |
|---------|-------------|---------|-----|
| `v`     | Screen recording + Log capture | ✅ | ✅ |
| `s`     | Screenshot | ✅ | ✅ |
| `r`     | Switch platform | ✅ | ✅ |
| `q`     | Quit | ✅ | ✅ |

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

### Option 1: Run directly in terminal

```bash
# Grant execute permission (only needed once)
chmod +x Recorder.sh

# Run
./Recorder.sh
```

### Option 2: Double-click the `.command` file

Double-click `Recorder.command` in Finder to automatically open Terminal and run the script.

> First-time use requires execute permission: `chmod +x Recorder.command`

## Workflow

```
1. Select platform → Android (1) / iOS (2)
2. Detect device connection status
3. Choose an action:
   ├── v: Screen recording (press any key to stop)
   ├── s: Screenshot
   ├── r: Switch platform
   └── q: Quit
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
├── Recorder.command    # Double-click to run (macOS)
└── Recorder.sh         # Main script
```

## System Requirements

- macOS (with zsh)
- Android devices must have **USB Debugging** enabled
- iOS devices must be connected via USB and trusted by the computer
