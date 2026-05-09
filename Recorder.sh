#!/bin/zsh

# Trap Ctrl+C / kill signals to ensure cleanup is performed
trap TearDown SIGINT SIGTERM

CONFIG_FILE="$HOME/.mobilerecorder_config"
ADB_CMD=""
IDB_CMD=""

# ============== Setup Functions ==============

check_brew() {
	if command -v brew &>/dev/null; then
		printf "\033[1;32m✓ Homebrew found:\033[0m %s\n" "$(command -v brew)"
		return 0
	else
		printf "\033[0;31m✗ Homebrew not found\033[0m\n"
		printf "  Please install Homebrew first: https://brew.sh\n"
		printf "  Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n"
		return 1
	fi
}

check_tool() {
	local tool=$1
	local path=""
	path=$(command -v "$tool" 2>/dev/null)
	if [[ -n "$path" ]]; then
		printf "\033[1;32m✓ %s found:\033[0m %s\n" "$tool" "$path"
		echo "$path"
		return 0
	fi

	# Try finding via known paths and env vars
	local found=""
	found=$(find_tool_paths "$tool")
	if [[ -n "$found" ]]; then
		printf "\033[1;32m✓ %s found:\033[0m %s\n" "$tool" "$found"
		echo "$found"
		return 0
	fi

	printf "\033[0;33m✗ %s not found\033[0m\n" "$tool"
	return 1
}

# Resolve env vars from shell config files and search known paths
resolve_shell_var() {
	local var_name=$1
	local value=""

	# Check current env first
	value="${(P)var_name}"
	if [[ -n "$value" ]]; then
		echo "$value"
		return
	fi

	# Parse shell config files for export statements
	local config_files=(
		"$HOME/.zshrc"
		"$HOME/.zprofile"
		"$HOME/.zshenv"
		"$HOME/.bash_profile"
		"$HOME/.bashrc"
	)
	for cfg in "${config_files[@]}"; do
		if [[ -f "$cfg" ]]; then
			# Match: export VAR=value or export VAR="value"
			local match=$(grep -E "^\s*export\s+${var_name}\s*=" "$cfg" 2>/dev/null | tail -1)
			if [[ -n "$match" ]]; then
				value=$(echo "$match" | sed -E "s/.*=\s*[\"']?([^\"'#]*)[\"']?.*/\1/")
				# Resolve $HOME and ~
				value="${value//\$HOME/$HOME}"
				value="${value//\~/$HOME}"
				echo "$value"
				return
			fi
		fi
	done
}

find_tool_paths() {
	local tool=$1
	local candidates=()

	case "$tool" in
	"adb")
		# Check ANDROID_HOME / ANDROID_SDK_ROOT
		for var in ANDROID_HOME ANDROID_SDK_ROOT ANDROID_SDK; do
			local sdk_dir=$(resolve_shell_var "$var")
			if [[ -n "$sdk_dir" && -x "$sdk_dir/platform-tools/adb" ]]; then
				echo "$sdk_dir/platform-tools/adb"
				return
			fi
		done
		# Known paths
		candidates=(
			"$HOME/Library/Android/sdk/platform-tools/adb"
			"/opt/homebrew/bin/adb"
			"/usr/local/bin/adb"
			"$HOME/Android/Sdk/platform-tools/adb"
		)
		;;
	"idb")
		candidates=(
			"/opt/homebrew/bin/idb"
			"/usr/local/bin/idb"
			"$HOME/.local/bin/idb"
			"$HOME/Library/Python/3.9/bin/idb"
			"$HOME/Library/Python/3.10/bin/idb"
			"$HOME/Library/Python/3.11/bin/idb"
			"$HOME/Library/Python/3.12/bin/idb"
			"$HOME/Library/Python/3.13/bin/idb"
		)
		;;
	esac

	for p in "${candidates[@]}"; do
		if [[ -x "$p" ]]; then
			echo "$p"
			return
		fi
	done
}

run_setup() {
	printf "\n\033[1;36m╔══════════════════════════════════════╗\033[0m\n"
	printf "\033[1;36m║     MobileRecorder Setup Wizard      ║\033[0m\n"
	printf "\033[1;36m╚══════════════════════════════════════╝\033[0m\n\n"

	# Check Homebrew
	printf "\033[1;34m[1/3] Checking Homebrew...\033[0m\n"
	if ! check_brew; then
		printf "\n\033[0;31mSetup cannot continue without Homebrew.\033[0m\n"
		return 1
	fi

	# Check adb
	printf "\n\033[1;34m[2/3] Checking adb (Android Debug Bridge)...\033[0m\n"
	local adb_path=""
	adb_path=$(check_tool adb)
	if [[ $? -ne 0 ]]; then
		printf "  (i) Install via Homebrew\n"
		printf "  (p) Enter path manually\n"
		printf "  (s) Skip\n"
		printf "  Choose [i/p/s] > "
		read adb_choice
		case "$adb_choice" in
		i|I)
			printf "\033[1;34m  Installing adb...\033[0m\n"
			brew install --cask android-platform-tools
			adb_path=$(command -v adb 2>/dev/null)
			if [[ -n "$adb_path" ]]; then
				printf "\033[1;32m  ✓ adb installed successfully:\033[0m %s\n" "$adb_path"
			else
				printf "\033[0;31m  ✗ adb installation failed\033[0m\n"
			fi
			;;
		p|P)
			printf "  Enter full path to adb (e.g. /opt/android-sdk/platform-tools/adb): "
			read custom_adb
			if [[ -x "$custom_adb" ]]; then
				adb_path="$custom_adb"
				printf "\033[1;32m  ✓ adb verified:\033[0m %s\n" "$adb_path"
			else
				printf "\033[0;31m  ✗ File not found or not executable: %s\033[0m\n" "$custom_adb"
			fi
			;;
		*)
			printf "  Skipping adb.\n"
			;;
		esac
	fi

	# Check idb
	printf "\n\033[1;34m[3/3] Checking idb (iOS Debug Bridge)...\033[0m\n"
	local idb_path=""
	idb_path=$(check_tool idb)
	if [[ $? -ne 0 ]]; then
		printf "  (i) Install via Homebrew + pip\n"
		printf "  (p) Enter path manually\n"
		printf "  (s) Skip\n"
		printf "  Choose [i/p/s] > "
		read idb_choice
		case "$idb_choice" in
		i|I)
			printf "\033[1;34m  Installing idb-companion...\033[0m\n"
			brew tap facebook/fb
			brew install idb-companion
			printf "\033[1;34m  Installing fb-idb (Python)...\033[0m\n"
			pip3 install fb-idb
			idb_path=$(command -v idb 2>/dev/null)
			if [[ -n "$idb_path" ]]; then
				printf "\033[1;32m  ✓ idb installed successfully:\033[0m %s\n" "$idb_path"
			else
				printf "\033[0;31m  ✗ idb installation failed\033[0m\n"
			fi
			;;
		p|P)
			printf "  Enter full path to idb (e.g. /usr/local/bin/idb): "
			read custom_idb
			if [[ -x "$custom_idb" ]]; then
				idb_path="$custom_idb"
				printf "\033[1;32m  ✓ idb verified:\033[0m %s\n" "$idb_path"
			else
				printf "\033[0;31m  ✗ File not found or not executable: %s\033[0m\n" "$custom_idb"
			fi
			;;
		*)
			printf "  Skipping idb.\n"
			;;
		esac
	fi

	# Save config
	cat > "$CONFIG_FILE" <<EOF
# MobileRecorder tool paths (auto-generated)
ADB_CMD="${adb_path}"
IDB_CMD="${idb_path}"
EOF

	# Summary
	printf "\n\033[1;36m══════════════ Setup Complete ══════════════\033[0m\n"
	if [[ -n "$adb_path" ]]; then
		printf "\033[1;32m  ✓ adb:\033[0m %s\n" "$adb_path"
	else
		printf "\033[0;33m  ✗ adb: not installed\033[0m\n"
	fi
	if [[ -n "$idb_path" ]]; then
		printf "\033[1;32m  ✓ idb:\033[0m %s\n" "$idb_path"
	else
		printf "\033[0;33m  ✗ idb: not installed\033[0m\n"
	fi
	printf "\033[1;36m  Config saved to: %s\033[0m\n" "$CONFIG_FILE"
	printf "\033[1;36m  Run with --setup to reconfigure anytime.\033[0m\n"
	printf "\033[1;36m════════════════════════════════════════════\033[0m\n\n"
}

load_config() {
	if [[ -f "$CONFIG_FILE" ]]; then
		source "$CONFIG_FILE"
	fi
}

validate_tools() {
	if [[ ! -f "$CONFIG_FILE" ]]; then
		printf "\033[1;33mFirst time setup detected. Running setup wizard...\033[0m\n"
		run_setup
		load_config
		return
	fi

	load_config

	# Verify stored paths still exist
	local needs_reconfig=0
	if [[ -n "$ADB_CMD" && ! -x "$ADB_CMD" ]]; then
		printf "\033[0;33m⚠ Previously configured adb not found at: %s\033[0m\n" "$ADB_CMD"
		needs_reconfig=1
	fi
	if [[ -n "$IDB_CMD" && ! -x "$IDB_CMD" ]]; then
		printf "\033[0;33m⚠ Previously configured idb not found at: %s\033[0m\n" "$IDB_CMD"
		needs_reconfig=1
	fi

	if [[ $needs_reconfig -eq 1 ]]; then
		printf "Re-run setup? (y/n) > "
		read rerun
		if [[ "$rerun" == "y" || "$rerun" == "Y" ]]; then
			run_setup
			load_config
		fi
	fi

	# Fallback: if config has empty paths, try to find them in PATH
	if [[ -z "$ADB_CMD" ]]; then
		ADB_CMD=$(command -v adb 2>/dev/null || true)
	fi
	if [[ -z "$IDB_CMD" ]]; then
		IDB_CMD=$(command -v idb 2>/dev/null || true)
	fi
}

# ============== Main Functions ==============

# Init
Init() {
	local platform=$1
	Exist "$platform"
	case $platform in
	"android")
		# Check if Android version is < 7
		AndroidVersionOver7
		# Set up output folder path for this session
		CreateFolder "AndroidRecorder"
		;;
	"ios")
		target_device=$("$IDB_CMD" list-targets | grep ooted | cut -d '|' -f 2 | tr -d ' ')
		CreateFolder "iOSRecorder"
		;;
	esac
}
# Init sub-function
Exist() {
	local platform=$1
	case $platform in
	"android")
		target_device=$("$ADB_CMD" devices | tr "\n" ':' | cut -d ':' -f 2)
		;;
	"ios")
		target_device=$("$IDB_CMD" list-targets | grep ooted | cut -d '|' -f 1,2,5)
		;;
	esac

	if [[ -n "$target_device" ]]; then
		printf "\033[1;34mCurrently connected device:\033[0m\n"
		printf "\033[1;35m%s\033[0m\n" "$target_device"
	else
		printf "\033[0;31mx ERROR: NO CONNECT/BOOT ANY %s DEVICE\033[0m\n" "$platform"
		TearDown
	fi
}
# Init sub-function
AndroidVersionOver7() {
	androidOsVersion=$("$ADB_CMD" shell getprop ro.build.version.release | cut -f1 -d .)
	androidVersionOver7=1
	local minVersion=7
	if [[ $androidOsVersion -lt $minVersion ]]; then
		androidVersionOver7=0
	fi
}
# Init sub-function
CreateFolder() {
	local platform=$1
	basePath="/Users/$(whoami)/Desktop/$platform"
	folderName=$(date +"%Y%m%d_%H%M%S")
	mkdir -p "$basePath/$folderName"
}
# Start
MainProcess() {
	printf "\033[1;34mStart Record Screen & Log or ScreenShot:\033[0m\n"
	printf "Videorecord: v,  Screenshot: s, change platform: r > "
	read process
	case $process in
	"v")
		case $platform in
		"android")
			printf "please enter package name for filter log , or not to enter > "
			read package
			Recorder "$package"
			;;
		"ios")
			Recorder
			;;
		esac
		;;
	"s")
		Screenshot
		;;
	"r")
		printf "Android: 1, iOS: 2 > "
		read newPlatform
		case $newPlatform in
		"1")
			platform="android"
			;;
		"2")
			platform="ios"
			;;
		*)
			printf "\033[0;31m𝘹 Error: Invalid Option\033[0m\n"
			return
			;;
		esac
		Init "$platform"
		;;
	"q")
		TearDown
		;;
	*)
		printf "\033[0;31m𝘹 Error: Invalid Option\033[0m\n"
		;;
	esac
}
# End
TearDown() {
	case $platform in
		"android")
			;;
		"ios")
			"$IDB_CMD" kill
			sleep 1
			kill $(pgrep -f idb | tr '\n' '\t') 2>/dev/null
			;;
	esac
	exit 0
}
###############
# Screen recored function
Recorder() {
	local package=$1
	case $platform in
	"android")
		if [[ -n "$package" ]]; then
			if ! CheckApp "$package"; then
				printf "\033[0;33m𝘹 Warning: The specified App (%s) is not running, all device logs will be recorded instead\033[0m\n" "$package"
				package=""
			fi
		fi
		Screenrecord
		Logcat "$package"
		;;
	"ios")
		Screenrecord
		Logcat
		;;
	esac
}
# Screen recored sub-function
CheckApp() {
	local package=$1
	if [[ $androidVersionOver7 == 1 ]]; then
		local isExist
		isExist=$("$ADB_CMD" shell pidof "$package")
		if [[ -n "$isExist" ]]; then
			return 0
		fi
	fi
	return 1
}
# Screen recored sub-function
Logcat() {
	local filename=Log-$startTime
	local package=$1

	printf "\033[1;34mGet Log File ...\033[0m\n"
	case $platform in
	"android")
		if [[ -z "$package" ]]; then
			"$ADB_CMD" logcat -t "$logStartTime" > "$basePath/$folderName/$filename.log"
		else
			if [[ $androidVersionOver7 == 1 ]]; then
				"$ADB_CMD" logcat -t "$logStartTime" --pid=$("$ADB_CMD" shell pidof "$package") > "$basePath/$folderName/$filename.log"
			elif [[ $androidVersionOver7 == 0 ]]; then
				"$ADB_CMD" logcat -t "$logStartTime" | grep "$package" > "$basePath/$folderName/$filename.log"
			fi
		fi
		;;
	"ios")
		"$IDB_CMD" log --udid "$target_device" > "$basePath/$folderName/$filename.log" 2>/dev/null &
		;;
	esac
}
# Screen recored sub-function
Screenrecord() {
	logStartTime=$(date +"%m-%d %T.000")
	startTime=$(date +"%Y%m%d_%H%M%S")
	local filename=Screenrecord-$startTime

	printf "\033[1;34mStart recording ...\033[0m\n"
	case $platform in
	"android")
		"$ADB_CMD" shell screenrecord --size 480x800 "/sdcard/$filename.mp4" > /dev/null 2>&1 &
		screenRecorderPID=$!
		printf "Press any key to stop recording ..."
		read -k 1 -s -r
		kill "$screenRecorderPID"
		sleep 1
		"$ADB_CMD" pull "/sdcard/$filename.mp4" "$basePath/$folderName"
		"$ADB_CMD" shell rm -f "/sdcard/$filename.mp4"
		;;
	"ios")
		"$IDB_CMD" record video --udid "$target_device" "$basePath/$folderName/$filename.mp4" > /dev/null 2>&1 &
		local recorderPID=$!
		sleep 3
		printf "Press any key to stop recording ..."
		read -k 1 -s -r
		echo ""
		kill -INT "$recorderPID" 2>/dev/null
		wait "$recorderPID" 2>/dev/null
		printf "\033[1;34mRecording saved.\033[0m\n"
		;;
	esac
}
# Screen recored sub-function
Screenshot() {
	startTime=$(date +"%Y%m%d_%H%M%S")
	local filename=Screenshot-$startTime

	printf "\033[1;34mGet Screenshot ...\033[0m\n"
	case $platform in
	"android")
		"$ADB_CMD" shell screencap -p "/sdcard/$filename.png"
		"$ADB_CMD" pull "/sdcard/$filename.png" "$basePath/$folderName"
		"$ADB_CMD" shell rm -f "/sdcard/$filename.png"
		;;
	"ios")
		"$IDB_CMD" screenshot --udid "$target_device" "$basePath/$folderName/$filename.png"
		;;
	esac
}

# ----------------------------------------------

# Handle --setup flag
if [[ "$1" == "--setup" ]]; then
	run_setup
	exit 0
fi

# Validate tools on startup
validate_tools

echo "Enter your test platform :"
printf "Android: 1, iOS: 2 > "
read platform
case $platform in
"1")
	platform="android"
	;;
"2")
	platform="ios"
	;;
*)
	printf "\033[0;31m𝘹 Error: Invalid Option\033[0m\n"
	exit 1
	;;
esac

Init "$platform"
while true; do
	echo ""
	MainProcess
done
