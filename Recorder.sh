#!/bin/zsh

# Trap Ctrl+C / kill signals to ensure cleanup is performed
trap TearDown SIGINT SIGTERM

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
		target_device=$(idb list-targets | grep ooted | cut -d '|' -f 2 | tr -d ' ')
		CreateFolder "iOSRecorder"
		;;
	esac
}
# Init sub-function
Exist() {
	local platform=$1
	case $platform in
	"android")
		target_device=$(adb devices | tr "\n" ':' | cut -d ':' -f 2)
		;;
	"ios")
		target_device=$(idb list-targets | grep ooted | cut -d '|' -f 1,2,5)
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
	androidOsVersion=$(adb shell getprop ro.build.version.release | cut -f1 -d .)
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
			idb kill
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
		isExist=$(adb shell pidof "$package")
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
			adb logcat -t "$logStartTime" > "$basePath/$folderName/$filename.log"
		else
			if [[ $androidVersionOver7 == 1 ]]; then
				adb logcat -t "$logStartTime" --pid=$(adb shell pidof "$package") > "$basePath/$folderName/$filename.log"
			elif [[ $androidVersionOver7 == 0 ]]; then
				adb logcat -t "$logStartTime" | grep "$package" > "$basePath/$folderName/$filename.log"
			fi
		fi
		;;
	"ios")
		idb log --udid "$target_device" > "$basePath/$folderName/$filename.log" 2>/dev/null &
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
		adb shell screenrecord --size 480x800 "/sdcard/$filename.mp4" > /dev/null 2>&1 &
		screenRecorderPID=$!
		printf "Press any key to stop recording ..."
		read -k 1 -s -r
		kill "$screenRecorderPID"
		sleep 1
		adb pull "/sdcard/$filename.mp4" "$basePath/$folderName"
		adb shell rm -f "/sdcard/$filename.mp4"
		;;
	"ios")
		idb record video --udid "$target_device" "$basePath/$folderName/$filename.mp4" > /dev/null 2>&1 &
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
		adb shell screencap -p "/sdcard/$filename.png"
		adb pull "/sdcard/$filename.png" "$basePath/$folderName"
		adb shell rm -f "/sdcard/$filename.png"
		;;
	"ios")
		idb screenshot --udid "$target_device" "$basePath/$folderName/$filename.png"
		;;
	esac
}

# ----------------------------------------------

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
