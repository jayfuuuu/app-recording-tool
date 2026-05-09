#!/bin/zsh

# Thin wrapper — double-click this file in Finder to launch Recorder.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/Recorder.sh" "$@"
