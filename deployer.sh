#!/bin/bash
### Author: Insality <insality@gmail.com>, 04.2019
## (c) Insality Games
##
## Universal build && deploy script for Defold projects (Android, iOS, HTML5, Linux, MacOS, Windows)
## Deployer has own settings, described in separate file settings_deployer
## See full deployer settings here: https://github.com/Insality/defold-deployer/blob/master/settings_deployer.template
##
## Install:
## See full instructions here: https://github.com/Insality/defold-deployer/blob/master/README.md
##
## Usage:
## bash deployer.sh [a][i][h][w][l][m][r][b][d] [--fast] [--no-resolve] [--instant] [--settings {filename}] [--headless] [--param {x}] [--steam]
## 	a - add target platform Android
## 	i - add target platform iOS
## 	h - add target platform HTML5
## 	w - add target platform Windows
## 	l - add target platform Linux
## 	m - add target platform MacOS
## 	r - set build mode to Release (Mac and Windows release builds will be automatically zipped)
## 	b - build project (game bundle will be in ./dist folder)
## 	d - deploy bundle to connected device
## 		it will deploy && run bundle on Android/iOS with reading logs to terminal
## 		for Android debug builds, it automatically handles the .debug suffix in package name
## 		for iOS, if multiple devices are detected, your last used device will be automatically selected
## 		your iOS device selection will be remembered and reused for both deployment and running
## 	--fast - only one Android platform, without resolve (for faster builds)
## 	--no-resolve - build without dependency resolve
## 	--headless - set mode to headless. Override release mode
## 	--settings {filename} - add settings file to build params. Can be used several times
## 	--param {x} - add flag {x} to bob.jar. Can be used several times
## 	--instant - it preparing bundle for Android Instant Apps. Always in release mode
##  --steam - upload release builds to Steam using SteamCMD (only works with release mode)
##  --reset-ios-device - reset the saved iOS device preference
##
## 	Example:
## 	./deployer.sh abd - build, deploy and run Android bundle
## 	./deployer.sh ibdr - build, deploy and run iOS release bundle
## 	./deployer.sh aibr - build Android and iOS release bundles
## 	./deployer.sh mbd - build MacOS debug build and run it
## 	./deployer.sh lbd --settings unit_test.txt --headless Build linux headless build with unit_test.txt settings and run it
## 	./deployer.sh wbr - build Windows release build
## 	./deployer.sh ab --instant - build Android release build for Android Instant Apps
##  ./deployer.sh wbr --steam - build Windows release build and upload it to Steam
##
## MIT License
###

clean() {
	# Clean up any running spinners and tick sounds first
	cleanup_spinner
	cleanup_tick_sound
	
	clean_build_settings

	if $is_build_started; then
		if $is_build_success; then
			echo -e "\x1B[32m[SUCCESS]: Build succesfully created\x1B[0m"
			echo -e "\x1B[32m[SUCCESS]: Build time: ${build_time} seconds\x1B[0m"
			echo -e "\x1B[32m[SUCCESS]: Build artifact: ${DEPLOYER_ARTIFACT_PATH}\x1B[0m"
		else
			echo -e "\x1B[31m[ERROR]: Build finished with errors\x1B[0m"
		fi
	else
		echo -e "Deployer end"
	fi
}

clean_build_settings() {
	rm -f ${version_settings_filename}
}

# Animated spinner functions for delightful build progress
spin() {
    local delay=0.15
    local animated_stars=("✨" "🌟" "⭐" "" "✦" "✧" "★")
    local fade_chars=("✧" "✦" "☆" "·")
    local sparkle_chars=("⚡️" "💥" "💫")
	local event_sparkle_chars=("⚡️" "🧚" "💥" "💫" "🧚‍♀️" "🧚‍♂️" "🧸" "🧞‍♂️" "🧞‍♀️" "🧞" "🪐" "🌎" "🌍")
    
    # Mini-game variables
    local collected_stars=0
    local special_stars_collected=0
    local rare_chance=5    # Start at 5% chance
    local legendary_chance=1  # Start at 1% chance
    local mythic_chance=0.1   # Start at 0.1% chance
    
    # Star collection types with display and points
    local common_stars=("⭐" "★" "☆")
    local rare_stars=("🌟" "✨" "💫")
    local legendary_stars=("🧚" "🧚‍♀️" "🧚‍♂️" "🧞" "🧞‍♀️" "🧞‍♂️")
    local mythic_stars=("🪐" "🌎" "🌍" "🌌" "🌠")
    
    # Collection tracking (bash 3.2 compatible)
    local common_count=0
    local rare_count=0
    local legendary_count=0
    local mythic_count=0
    
    local max_trail_length=999
    local cycle_count=0
    local trail_length=1
    local start_time=$(date +%s)
    
    # Enhanced rainbow colors with more variety
    local colors=(
        "\033[38;5;196m"  # Bright Red
        "\033[38;5;208m"  # Orange
        "\033[38;5;226m"  # Bright Yellow  
        "\033[38;5;118m"  # Bright Green
        "\033[38;5;45m"   # Cyan
        "\033[38;5;33m"   # Sky Blue
        "\033[38;5;129m"  # Purple
        "\033[38;5;201m"  # Magenta
        "\033[38;5;219m"  # Pink
    )
    local reset_color="\033[0m"
    local bold="\033[1m"
    
    tput civis  # Hide cursor
    
    while true; do
        # Star collection mini-game: Every tick, collect a trail star
        ((collected_stars++))
        
        # Increase special star chances based on collected stars
        if (( collected_stars % 10 == 0 )); then
            rare_chance=$(echo "scale=2; $rare_chance + 0.5" | bc)
            if (( collected_stars % 50 == 0 )); then
                legendary_chance=$(echo "scale=2; $legendary_chance + 0.25" | bc)
            fi
            if (( collected_stars % 100 == 0 )); then
                mythic_chance=$(echo "scale=2; $mythic_chance + 0.05" | bc)
            fi
        fi
        
        # Check for special star encounters
        local random_val=$((RANDOM % 10000))
        local special_star_found=""
        local special_star_type=""
        
        if (( random_val < $(echo "$mythic_chance * 100" | bc | cut -d. -f1) )); then
            # Mythic star found!
            special_star_found="${mythic_stars[$((RANDOM % ${#mythic_stars[@]}))]}"
            special_star_type="mythic"
            ((mythic_count++))
            ((special_stars_collected++))
        elif (( random_val < $(echo "$legendary_chance * 100" | bc | cut -d. -f1) )); then
            # Legendary star found!
            special_star_found="${legendary_stars[$((RANDOM % ${#legendary_stars[@]}))]}"
            special_star_type="legendary"
            ((legendary_count++))
            ((special_stars_collected++))
        elif (( random_val < $(echo "$rare_chance * 100" | bc | cut -d. -f1) )); then
            # Rare star found!
            special_star_found="${rare_stars[$((RANDOM % ${#rare_stars[@]}))]}"
            special_star_type="rare"
            ((rare_count++))
            ((special_stars_collected++))
        fi
        
        # Calculate current trail length - grows more dynamically
        if (( cycle_count > 0 && cycle_count % 8 == 0 )); then
            if (( trail_length < max_trail_length )); then
                ((trail_length++))
            fi
        fi
        
        # Calculate elapsed time
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local elapsed_display="${elapsed}s"
        
        # Get animated leading star character with bold styling
        local star_idx=$((cycle_count % ${#animated_stars[@]}))
        local leading_color_idx=$((cycle_count % ${#colors[@]}))
        local leading_star="${bold}${colors[$leading_color_idx]}${animated_stars[$star_idx]}${reset_color}"
        
        # Build the magnificent rainbow star trail
        local display_trail=""
        for (( i=0; i < trail_length; i++ )); do
            # Create flowing rainbow effect with offset colors
            local trail_color_idx=$(( (cycle_count + i * 2) % ${#colors[@]} ))
            local trail_color="${colors[$trail_color_idx]}"
            
            if (( i == 0 )); then
                # Leading star - most brilliant
                display_trail="${leading_star}${display_trail}"
            elif (( i <= 2 )); then
                # Close trailing stars - bright and sparkly
                local sparkle_idx=$(( (cycle_count + i) % ${#sparkle_chars[@]} ))
                display_trail="${trail_color}${sparkle_chars[$sparkle_idx]}${reset_color}${display_trail}"
            elif (( i <= 6 )); then
                # Middle trail - fading stars
                local fade_idx=$(( (i-3) % ${#fade_chars[@]} ))
                display_trail="${trail_color}${fade_chars[$fade_idx]}${reset_color}${display_trail}"
            else
                # Long tail - subtle sparkles and dots
                local fade_pattern=$(( (cycle_count + i) % 4 ))
                if (( fade_pattern == 0 )); then
                    display_trail="${trail_color}·${reset_color}${display_trail}"
                elif (( fade_pattern == 1 )); then
                    display_trail="${trail_color}˙${reset_color}${display_trail}"
                else
                    display_trail="${trail_color}․${reset_color}${display_trail}"
                fi
            fi
        done
        
        # Build collection display
        local collection_display=""
        if (( collected_stars > 0 )); then
            # Add regular stars collected
            collection_display+=" ⭐${collected_stars}"
            
            # Add special stars if any collected
            if (( rare_count > 0 )); then
                collection_display+=" 🌟${rare_count}"
            fi
            if (( legendary_count > 0 )); then
                collection_display+=" 🧚${legendary_count}"
            fi
            if (( mythic_count > 0 )); then
                collection_display+=" 🪐${mythic_count}"
            fi
        fi
        
        # Show special star found notification
        local special_notification=""
        if [ -n "$special_star_found" ]; then
            case $special_star_type in
                "rare")
                    special_notification=" \033[38;5;226m✨ RARE! ${special_star_found}\033[0m"
                    ;;
                "legendary")
                    special_notification=" \033[38;5;201m💫 LEGENDARY! ${special_star_found}\033[0m"
                    ;;
                "mythic")
                    special_notification=" \033[38;5;196m🌟 MYTHIC! ${special_star_found}\033[0m"
                    ;;
            esac
        fi
        
        # Show the magnificent sparkling trail with collection stats
        printf "\r\033[K${display_trail} ${elapsed_display}${collection_display}${special_notification}"
        sleep $delay
        ((cycle_count++))
    done
}

# Global variable to track spinner PID for cleanup
SPINNER_PID=""

cleanup_spinner() {
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
        SPINNER_PID=""
        printf "\r\033[K"  # Clear spinner line
        tput cnorm  # Show cursor
    fi
}

# Enhanced progress display with combined spinner and stats
show_progress_with_spinner() {
    local step_description="$1"
    local show_progress="$2"  # "true" to show progress bar below spinner
    shift 2
    
    # Show step start message with timestamp
    if [ -n "$step_description" ]; then
        echo "[$(date +'%H:%M:%S')] $step_description"
    fi
    
    local step_start_time=$(date +%s)
    
    # Simple execution without spinner - sparkle animation disabled
    "$@"
    local exit_code=$?
    
    # Calculate completion time
    local step_end_time=$(date +%s)
    local step_duration=$((step_end_time - step_start_time))
    
    # Show completion message
    if [ $exit_code -eq 0 ]; then
        if [ -n "$step_description" ]; then
            echo -e "\n\033[32m[✅ SUCCESS]\033[0m Completed in ${step_duration}s"
        else
            echo -e "\033[32m[✅]\033[0m Completed"
        fi
    else
        if [ -n "$step_description" ]; then
            echo -e "\n\033[31m[❌ FAILED]\033[0m After ${step_duration}s (exit code: $exit_code)"
        else
            echo -e "\033[31m[❌]\033[0m Failed (exit code: $exit_code)"
        fi
    fi

    # Sound effect for completion
    if [ $exit_code -eq 0 ]; then
        afplay /System/Library/Sounds/Glass.aiff
    else
        afplay /System/Library/Sounds/Basso.aiff
    fi

    return $exit_code
}

# Legacy wrapper for backward compatibility
start_spinner() {
    show_progress_with_spinner "$@" "false"
}


### Exit on Cmd+C / Ctrl+C
# Global variable to track tick sound PID for cleanup
TICK_PID=""

cleanup_tick_sound() {
    if [ -n "$TICK_PID" ]; then
        kill $TICK_PID 2>/dev/null
        wait $TICK_PID 2>/dev/null
        TICK_PID=""
    fi
}

# Enhanced trap handling to ensure proper cleanup on interruption
handle_interrupt() {
	echo -e "\n\x1B[33m[INTERRUPTED]: Script cancelled by user\x1B[0m"
	cleanup_spinner
	cleanup_tick_sound
	exit 130
}

trap handle_interrupt INT
trap clean EXIT
set -e

### Early argument parsing for special commands that don't require game.project
ios_device_preference_filename=".ios_device_preference"
for arg in "$@"; do
	if [ "$arg" == "--reset-ios-device" ]; then
		if [ -f "$ios_device_preference_filename" ]; then
			rm -f "$ios_device_preference_filename"
			echo -e "\x1B[32mReset iOS device preference\x1B[0m"
		else
			echo -e "\x1B[33mNo iOS device preference found to reset\x1B[0m"
		fi
		exit 0
	fi
done

if [ ! -f ./game.project ]; then
	echo -e "\x1B[31m[ERROR]: ./game.project not exist\x1B[0m"
	exit
fi

### Export values
# DEPLOYER_ARTIFACT_PATH - path to build artifact (for example, .app file)

### Default variables
use_latest_bob=false
is_live_content=false
pre_build_script=false
post_build_script=false
no_strip_executable=false
is_build_html_report=false
enable_incremental_version=false
enable_incremental_android_version_code=false
is_steam_upload=false
steam_app_id=""
steam_depot_id=""
steam_depot_id_windows=""
steam_depot_id_macos=""
steam_username=""
steam_vdf_path=""

### Settings loading
settings_filename="settings_deployer"
script_path="`dirname \"$0\"`"
progress_script="${script_path}/progress.js"
is_settings_exist=false

if [ -f ${script_path}/${settings_filename} ]; then
	is_settings_exist=true
	echo -e "Using default deployer settings from \x1B[33m${script_path}/${settings_filename}\x1B[0m"
	source ${script_path}/${settings_filename}
fi

if [ -f ./${settings_filename} ]; then
	is_settings_exist=true
	echo -e "Using custom deployer settings from \x1B[33m${PWD}/${settings_filename}\x1B[0m"
	source ./${settings_filename}
fi

if ! $is_settings_exist ; then
	echo -e "\x1B[31m[ERROR]: No deployer settings file founded\x1B[0m"
	echo "Place your default deployer settings at ${script_path}/"
	echo "Place your project settings at root of your game project (./)"
	echo "File name should be '${settings_filename}'"
	echo "See settings template here: https://github.com/Insality/defold-deployer"
	exit
fi

### Load transporter credentials from environment variables or zshrc
load_transporter_credentials() {
	# First try environment variables
	if [ -n "$TRANSPORTER_USERNAME" ] && [ -n "$TRANSPORTER_PASSWORD" ] && [ -n "$TRANSPORTER_TEAM_ID" ]; then
		transporter_username="$TRANSPORTER_USERNAME"
		transporter_password="$TRANSPORTER_PASSWORD"
		transporter_team_id="$TRANSPORTER_TEAM_ID"
		return 0
	fi

	# If environment variables are not set, try to load from zshrc
	if [ -f ~/.zshrc ]; then
		echo "Loading transporter credentials from ~/.zshrc..."
		# Extract the export lines and evaluate them
		eval $(grep "export TRANSPORTER_USERNAME=" ~/.zshrc)
		eval $(grep "export TRANSPORTER_PASSWORD=" ~/.zshrc)
		eval $(grep "export TRANSPORTER_TEAM_ID=" ~/.zshrc)

		transporter_username="$TRANSPORTER_USERNAME"
		transporter_password="$TRANSPORTER_PASSWORD"
		transporter_team_id="$TRANSPORTER_TEAM_ID"
	else
		transporter_username=""
		transporter_password=""
		transporter_team_id=""
	fi
}

load_transporter_credentials


### Constants
build_date=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
android_platform="armv7-android"
ios_platform="arm64-ios"
html_platform="js-web"
linux_platform="x86_64-linux"
windows_platform="x86_64-win32"
macos_platform="x86_64-macos"
version_settings_filename="deployer_version_settings.txt"
ios_device_preference_filename=".ios_device_preference"
selected_ios_device_id=""  # Global variable to store selected device ID for reuse
build_output_folder="./build/default_deployer"
dist_folder="./dist"
bundle_folder="${dist_folder}/bundle"
commit_sha="unknown"
commits_count=0
is_git=false
is_cache_using=false

if [ -d .git ]; then
	commit_sha=`git rev-parse --verify HEAD`
	commits_count=`git rev-list --all --count`
	is_git=true
fi


### Runtime
is_build_success=false
is_build_started=false
build_time=false

### Game project settings for deployer script
title=$(less game.project | grep "^title = " | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')
version=$(less game.project | grep "^version = " | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')
version=${version:='0.0.0'}
title_no_space=$(echo -e "${title}" | tr -cd '[:alnum:]') # removes spaces, hyphens and special characters
bundle_id_android=$(less game.project | grep "^package = " | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')
bundle_id_ios=$(less game.project | grep "^bundle_identifier = " | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')
### Override last version number with commits count
if $enable_incremental_version; then
	version="${version%.*}.$commits_count"
fi

file_prefix_name="${title_no_space}_${version}-${commits_count}"
version_folder="${bundle_folder}/${version}-${commits_count}"
echo -e "\nProject: \x1B[36m${title} v${version}\x1B[0m"
echo -e "Commit SHA: \x1B[35m${commit_sha}\x1B[0m"
echo -e "Commits amount: \x1B[33m${commits_count}\x1B[0m"

### Bob select
bob_version="$(cut -d ":" -f1 <<< "$bob_sha")"
bob_sha="$(cut -d ":" -f2 <<< "$bob_sha")"
bob_channel="${bob_channel:-"stable"}"

if $use_latest_bob; then
        INFO=$(curl -s http://d.defold.com/${bob_channel}/info.json)
        echo "Using latest bob: ${INFO}"
        bob_sha=$(sed 's/.*sha1": "\(.*\)".*/\1/' <<< $INFO)
        bob_version=$(sed 's/[^0-9.]*\([0-9.]*\).*/\1/' <<< $INFO)
        bob_version="$(cut -d "." -f3 <<< "$bob_version")"
    fi

# Function to play tick sound
play_tick_sound() {
    while true; do
        afplay /System/Library/Sounds/Morse.aiff
        sleep 1
    done
}

echo -e "Using Bob version \x1B[35m${bob_version}\x1B[0m SHA: \x1B[35m${bob_sha}\x1B[0m"

bob_path="${bob_folder}bob${bob_version}.jar"
download_bob() {
	if [ ! -f ${bob_path} ]; then
		# Create the bob folder if it doesn't exist
		mkdir -p "${bob_folder}"

		BOB_URL="https://d.defold.com/archive/${bob_channel}/${bob_sha}/bob/bob.jar"
		echo "Unable to find bob${bob_version}.jar. Downloading it from d.defold.com: ${BOB_URL}}"
	# Show progress for downloading Bob with enhanced display
	echo "[🔽] Downloading Bob build tool..."
	curl -L -o ${bob_path} ${BOB_URL}
	echo "[✅] Bob download complete"
	fi
}
download_bob

real_bob_sha=$(java -jar ${bob_path} --version | cut -d ":" -f3 | cut -d " " -f2)
if [ ! ${real_bob_sha} == ${bob_sha} ]; then
	echo "Bob SHA mismatch (file bob SHA and settings bob SHA). Redownloading..."
	rm ${bob_path}
	download_bob
fi


try_fix_libraries() {
	echo "Possibly, libs was corrupted (script interrupted while resolving libraries)"
	echo "Trying to delete and redownload it (./.internal/lib/)"
	rm -r ./.internal/lib/
	java -jar ${bob_path} --email foo@bar.com --auth 12345 resolve
}


add_to_gitignore() {
	if [ ! $is_git ]; then
		return 0
	fi

	if [ ! -f ./.gitignore ]; then
		touch .gitignore
		echo -e "\Create .gitignore file" >&2
	fi

	if ! grep -Fxq "$1" .gitignore; then
		echo "Add $1 to .gitignore" >&2
		echo -e "\n$1" >> .gitignore
	fi
}


write_report() {
	if [ -z "$build_stats_report_file" ]; then
		return 0
	fi

	if [ ! -f $build_stats_report_file ]; then
		touch $build_stats_report_file
		echo -e "Create build report file: $build_stats_report_file"

		echo "date,sha,version,build_size,build_time,platform,mode,is_cache_using,commits_count" >> $build_stats_report_file
	fi

	platform=$1
	mode=$2
	target_path=$3
	build_size=$(du -sh -k ${target_path} | cut -f1)
	echo "$build_date,$commit_sha,$version,$build_size,$build_time,$platform,$mode,$is_cache_using,$commits_count" >> $build_stats_report_file
}


resolve_bob() {
	# Show progress for library resolution with enhanced spinner
	echo "[📦] Resolving project dependencies..."
	java -jar ${bob_path} --email foo@bar.com --auth 12345 resolve || try_fix_libraries
	echo "[✅] Dependencies resolved"
	echo ""
}


bob() {
	mode=$1
	java --version
	java -jar ${bob_path} --version

	args="java -jar ${bob_path} --archive --output ${build_output_folder} --bundle-output ${dist_folder} --variant $@"

	if ! $no_strip_executable; then
		args+=" --strip-executable"
	fi

	if [ ${mode} == "debug" ]; then
		echo -e "\nBuild without distclean. Compression enabled, Debug mode"
		args+=" --texture-compression true build bundle"
	fi

	if [ ${mode} == "release" ]; then
		echo -e "\nBuild with distclean and compression. Release mode"
		args+=" --texture-compression true build bundle distclean"
	fi

	if [ ${mode} == "headless" ]; then
		echo -e "\nBuild with distclean and without compression. Headless mode"
		args+=" build bundle distclean"
	fi

    start_build_time=`date +%s`

    # Start tick sound in the background
    play_tick_sound &
    TICK_PID=$!

    echo -e "Build command: ${args}"
    echo "[🔨] Building project with Bob..."
    echo "\n=== BUILD OUTPUT ==="

    # Run the build command with progress spinner
    show_progress_with_spinner "Building with Bob" "true" ${args}
    local build_exit_code=$?

    # Stop the tick sound
    kill $TICK_PID 2>/dev/null
    wait $TICK_PID 2>/dev/null

	echo "\n=== END BUILD OUTPUT ==="

	if [ $build_exit_code -eq 0 ]; then
		echo "[✅] Build process completed successfully"
	else
		echo "[❌] Build process FAILED with exit code: $build_exit_code"
		return $build_exit_code
	fi

	build_time=$((`date +%s`-start_build_time))
	echo -e "Build time: $build_time seconds\n"
}


build() {
	if [ -f ./${pre_build_script} ]; then
		echo "Run pre-build script: $pre_build_script"
		source ./$pre_build_script
	fi

	#clean first
	rm -f -r ./.deployer_cache ./build

	mkdir -p ${version_folder}

	platform=$1
	mode=$2
	additional_params="${build_params} ${settings_params} $3"
	is_build_success=false
	is_build_started=true

	if [ ${mode} == "release" ]; then
		ident=${ios_identity_dist}
		prov=${ios_prov_dist}
		android_keystore=${android_keystore_dist}
		android_keystore_password=${android_keystore_password_dist}
		android_keystore_alias=${android_keystore_alias_dist}
		echo -e "\x1B[32mBuild in Release mode\x1B[0m"
	fi
	if [ ${mode} == "debug" ]; then
		ident=${ios_identity_dev}
		prov=${ios_prov_dev}
		android_keystore=${android_keystore_dev}
		android_keystore_password=${android_keystore_password_dev}
		android_keystore_alias=${android_keystore_alias_dev}
		echo -e "\x1B[31mBuild in Debug mode\x1B[0m"
	fi
	if [ ${mode} == "headless" ]; then
		ident=${ios_identity_dev}
		prov=${ios_prov_dev}
		android_keystore=${android_keystore_dev}
		android_keystore_password=${android_keystore_password_dev}
		android_keystore_alias=${android_keystore_alias_dev}
		echo -e "\x1B[34mBuild in Headless mode\x1B[0m"
	fi

	if $is_resolve; then
		resolve_bob
	fi

	if [ ! -z "$exclude_folders" ]; then
		additional_params=" --exclude-build-folder $exclude_folders $additional_params"
	fi

	if [ ! -z "$resource_cache_local" ]; then
		echo "Use resource local cache for bob builder: $resource_cache_local"
		additional_params=" --resource-cache-local $resource_cache_local $additional_params"
		is_cache_using=true
		add_to_gitignore $resource_cache_local
	fi

	filename="${file_prefix_name}_${mode}"

	platform_folder="${version_folder}/${platform}"

	rm -rf ${platform_folder}
	mkdir $platform_folder

	# Android platform
	if [ ${platform} == ${android_platform} ]; then
		line="${dist_folder}/${title_no_space}/${title_no_space}"

		if $is_fast_debug; then
			echo "Build only one platform for faster build"
			additional_params=" -ar armv7-android $additional_params"
		fi

		if $is_live_content; then
			echo "Add publishing live content to build"
			additional_params=" -l yes $additional_params"
		fi

		if [ ! -z "$android_keystore_alias" ]; then
			additional_params=" --keystore-alias $android_keystore_alias $additional_params"
		fi

		if $is_build_html_report; then
			additional_params=" -brhtml ${version_folder}/Android_report.html $additional_params"
		fi

		if [ ! -z "$settings_android" ]; then
			additional_params="$additional_params --settings $settings_android"
		fi

		bob ${mode} --platform ${platform} --bundle-format apk,aab --keystore ${android_keystore} \
			--keystore-pass ${android_keystore_password} \
			--build-server ${build_server} ${additional_params}

		target_path="${platform_folder}/${filename}.apk"
		mv "${line}.apk" ${target_path} && is_build_success=true

		rm -f "${platform_folder}/${filename}.aab"
		mv "${line}.aab" "${platform_folder}/${filename}.aab" && is_build_success=true
		export DEPLOYER_ARTIFACT_PATH="${target_path}"

		#if [ ${mode} == "release" ]; then
			# TODO: upload to Play Store
		#fi
	fi

	# iOS platform
	if [ ${platform} == ${ios_platform} ]; then
		# For iOS, Bob creates files using the actual title, not title_no_space
		line="${dist_folder}/${title}"

		if $is_build_html_report; then
			additional_params=" -brhtml ${version_folder}/iOS_report.html $additional_params"
		fi

		if $is_live_content; then
			echo "Add publishing live content to build"
			additional_params=" -l yes $additional_params"
		fi

		if [ ! -z "$settings_ios" ]; then
			additional_params="$additional_params --settings $settings_ios"
		fi

		bob ${mode} --platform ${platform} --architectures arm64-ios --identity ${ident} --mobileprovisioning ${prov} \
			--build-server ${build_server} ${additional_params}

		# Debug: Show what files were actually created
		echo "Checking for build artifacts in ${dist_folder}..."
		ls -la "${dist_folder}" || echo "dist folder not found"
		echo "Looking for iOS artifacts with pattern: ${line}.*"
		find "${dist_folder}" -name "${title}*" -type f 2>/dev/null || echo "No iOS artifacts found matching ${title}"

		target_path="${platform_folder}/${filename}.ipa"
		rm -rf ${target_path}
		
		# Try to find and move the .ipa file
		if [ -f "${line}.ipa" ]; then
			echo "Found .ipa file: ${line}.ipa"
			mv "${line}.ipa" ${target_path} && is_build_success=true
		else
			echo "Expected .ipa file not found at: ${line}.ipa"
			# Try to find any .ipa file in the dist folder
			ipa_file=$(find "${dist_folder}" -name "*.ipa" -type f | head -1)
			if [ -n "$ipa_file" ]; then
				echo "Found alternative .ipa file: $ipa_file"
				mv "$ipa_file" ${target_path} && is_build_success=true
			else
				echo "No .ipa file found in ${dist_folder}"
			fi
		fi

		rm -rf "${platform_folder}/${filename}.app"
		
		# Try to find and move the .app file
		if [ -d "${line}.app" ]; then
			echo "Found .app bundle: ${line}.app"
			mv "${line}.app" "${platform_folder}/${filename}.app"
		else
			echo "Expected .app bundle not found at: ${line}.app"
			# Try to find any .app bundle in the dist folder
			app_bundle=$(find "${dist_folder}" -name "*.app" -type d | head -1)
			if [ -n "$app_bundle" ]; then
				echo "Found alternative .app bundle: $app_bundle"
				mv "$app_bundle" "${platform_folder}/${filename}.app"
			else
				echo "No .app bundle found in ${dist_folder}"
			fi
		fi

		export DEPLOYER_ARTIFACT_PATH="${target_path}"

		# Upload to Transporter if this is a release build
		#if [ ${mode} == "release" ]; then
		#	upload_to_transporter "${target_path}"
		#fi
	fi

	# HTML5 platform
	if [ ${platform} == ${html_platform} ]; then
		line="${dist_folder}/${title}"

		if $is_build_html_report; then
			additional_params=" -brhtml ${version_folder}/HTML5_report.html $additional_params"
		fi

		if [ ! -z "$settings_html" ]; then
			additional_params="$additional_params --settings $settings_html"
		fi

		echo "Start build HTML5 ${mode}"
		bob ${mode} --platform ${platform} --architectures js-web ${additional_params}

		target_path="${platform_folder}/${filename}_html.zip"

		rm -rf "${platform_folder}/${filename}_html"
		rm -f "${target_path}"
		mv "${line}" "${platform_folder}/${filename}_html"

		previous_folder=`pwd`
		cd "${platform_folder}"
		zip "${filename}_html.zip" -r "${filename}_html" && is_build_success=true
		cd "${previous_folder}"

		export DEPLOYER_ARTIFACT_PATH="${target_path}"
	fi

	# Linux platform
	if [ ${platform} == ${linux_platform} ]; then
		line="${dist_folder}/${title}"

		if $is_build_html_report; then
			additional_params=" -brhtml ${version_folder}/Linux_report.html $additional_params"
		fi

		#if $is_live_content; then
		#	echo "Add publishing live content to build"
		#	additional_params=" -l yes $additional_params"
		#fi

		if [ ! -z "$settings_linux" ]; then
			additional_params="$additional_params --settings $settings_linux"
		fi

		echo "Start build Linux ${mode}"
		bob ${mode} --platform ${platform} ${additional_params}

		target_path="${platform_folder}/${filename}_linux"

		rm -rf ${target_path}
		mv "${line}" ${target_path} && is_build_success=true

		export DEPLOYER_ARTIFACT_PATH="${target_path}"

		if [ ${mode} == "release" ]; then
		if $is_steam_upload; then
				upload_to_steam ${platform} ${mode} ${target_path}
			fi
		fi
	fi

	# MacOS platform
	if [ ${platform} == ${macos_platform} ]; then
		line="${dist_folder}/${title}.app"

		if $is_build_html_report; then
			additional_params=" -brhtml ${version_folder}/macOS_report.html $additional_params"
		fi

		#if $is_live_content; then
			#echo "Add publishing live content to build"
			#additional_params=" -l yes $additional_params"
		#fi

		if [ ! -z "$settings_macos" ]; then
			additional_params="$additional_params --settings $settings_macos"
		fi

		echo "Start build MacOS ${mode}"
		bob ${mode} --platform ${platform} --build-server ${build_server} ${additional_params}

		target_path="${platform_folder}/${title}.app"

		rm -rf ${target_path}
		mv "${line}" ${target_path} && is_build_success=true

		export DEPLOYER_ARTIFACT_PATH="${target_path}"

		if [ ${mode} == "release" ]; then
			# Zip the macOS build
			zip_release_build ${platform} ${mode} ${target_path}

			if $is_steam_upload; then
				upload_to_steam ${platform} ${mode} ${target_path}
			fi
		fi
	fi

	# Windows platform
	if [ ${platform} == ${windows_platform} ]; then
		line="${dist_folder}/${title}"

		if $is_build_html_report; then
			additional_params=" -brhtml ${version_folder}/windows_report.html $additional_params"
		fi

		#if $is_live_content; then
			#echo "Add publishing live content to build"
			#additional_params=" -l yes $additional_params"
		#fi

		if [ ! -z "$settings_windows" ]; then
			additional_params="$additional_params --settings $settings_windows"
		fi

		echo "Start build Windows ${mode}"
		bob ${mode} --platform ${platform} ${additional_params}

		target_path="${platform_folder}/${filename}_windows"

		rm -rf ${target_path}
		mv "${line}" ${target_path} && is_build_success=true

		export DEPLOYER_ARTIFACT_PATH="${target_path}"

		if [ ${mode} == "release" ]; then
			# Zip the Windows build
			zip_release_build ${platform} ${mode} ${target_path}

			if $is_steam_upload; then
				upload_to_steam ${platform} ${mode} ${target_path}
			fi
		fi
	fi

	if $is_build_success; then
		echo -e "\x1B[32mSave bundle at ${version_folder}/${filename}\x1B[0m"
		if [ -f ./${post_build_script} ]; then
			echo "Run post-build script: $post_build_script"
			source ./$post_build_script
		fi

		mkdir -p "${platform_folder}/liveupdate_content"

		# Check for liveupdate content in build directory
		if [ -d "build/liveupdate_bundles" ] && [ -n "$(find build/liveupdate_bundles/ -maxdepth 1 -name '*.zip' -print -quit 2>/dev/null)" ]; then
			mv build/liveupdate_bundles/*.zip "${platform_folder}/liveupdate_content/resources_${version}.zip"
		fi

		write_report ${platform} ${mode} ${target_path}
	else
		echo -e "\x1B[31mError during building...\x1B[0m"
	fi
}


make_instant() {
	mode=$1
	echo -e "\nPreparing APK for Android Instant game"
	filename="${version_folder}/${file_prefix_name}_${mode}.apk"
	filename_instant="${version_folder}/${file_prefix_name}_${mode}_align.apk"
	filename_instant_zip="${version_folder}/${file_prefix_name}_${mode}.apk.zip"
	${sdk_path}/zipalign -f 4 ${filename} ${filename_instant}
	${sdk_path}/apksigner sign --key ${android_key_dist} --cert ${android_cer_dist} ${filename_instant}
	zip -j ${filename_instant_zip} ${filename_instant}
	rm ${filename}
	rm ${filename_instant}
	echo -e "\x1B[32mZip file for Android instant ready: ${filename_instant_zip}\x1B[0m"
}


deploy() {
	platform=$1
	mode=$2
	clean_build_settings

	platform_folder="${version_folder}/${platform}"

	if [ ${platform} == ${android_platform} ]; then
		filename="${platform_folder}/${file_prefix_name}_${mode}.apk"
		echo "Deploy to Android from ${filename}"
		adb install -r -d "${filename}"
	fi

	if [ ${platform} == ${ios_platform} ]; then
		# For iOS debug deployment, we use `xcrun devicectl device install`, which works with .app files
		filename="${platform_folder}/${file_prefix_name}_${mode}.app"
		echo "Deploy to iOS from ${filename}"

		# Get device identifier
		device_id=$(select_ios_device)
		if [ -z "$device_id" ]; then
			echo -e "\x1B[31m[ERROR]: No iOS device selected\x1B[0m"
			return 1
		fi

		# Store the selected device ID for reuse in run phase
		selected_ios_device_id="$device_id"

		echo "Installing app to device ${device_id}..."
		echo "Install command: xcrun devicectl device install app --device ${device_id} \"${filename}\""
		xcrun devicectl device install app --device ${device_id} "${filename}"

		if [ $? -ne 0 ]; then
			echo -e "\x1B[33m[WARNING]: devicectl install failed, trying ios-deploy as fallback...\x1B[0m"
			echo "Fallback command: ios-deploy -W --bundle ${filename} --bundle_id ${bundle_id_ios}"
			ios-deploy -W --bundle "${filename}" --bundle_id "${bundle_id_ios}"
		fi
	fi

	if [ ${platform} == ${html_platform} ]; then
		filename="${platform_folder}/${file_prefix_name}_${mode}_html/"
		echo "Start python server and open in browser ${filename:1}"

		open "http://localhost:8000${filename:1}"
		python3 --version
		python3 -m "http.server"
	fi

	if [ ${platform} == ${macos_platform} ]; then
		filename="${platform_folder}/${file_prefix_name}_${mode}_macos.app"
		echo "Deploy to MacOS from ${filename}"
		open $filename
	fi
}


run() {
	platform=$1
	mode=$2
	clean_build_settings

	platform_folder="${version_folder}/${platform}"

	if [ ${platform} == ${android_platform} ]; then
		# For debug builds, the package name has .debug appended
		app_package_id="${bundle_id_android}"
		if [ "${mode}" == "debug" ]; then
			app_package_id="${bundle_id_android}.debug"
			echo "Using debug package name: ${app_package_id}"
		fi
		adb shell am start -n ${app_package_id}/com.dynamo.android.DefoldActivity
		adb logcat -s defold
	fi

	if [ ${platform} == ${ios_platform} ]; then
		# with devicectl, we need to use the .app file
		filename_app="${platform_folder}/${file_prefix_name}_${mode}.app"
		# Unlike android debug builds, we don't need to add .debug to bundle_id for iOS

		# Use the device ID from deployment phase if available, otherwise select device
		device_id="$selected_ios_device_id"
		if [ -z "$device_id" ]; then
			device_id=$(select_ios_device)
			if [ -z "$device_id" ]; then
				echo -e "\x1B[31m[ERROR]: No iOS device selected\x1B[0m"
				return 1
			fi
		fi

		echo "Launching app on device ${device_id}..."

		echo "Using console mode..."
		launch_ios_app_with_console "$device_id" "$bundle_id_ios"
		launch_status=$?

		if [ $launch_status -ne 0 ]; then
			echo -e "\x1B[33m[WARNING]: devicectl console launch failed, trying ios-deploy as fallback...\x1B[0m"
			echo "Fallback command: ios-deploy -I -m -b ${filename_app}"
			ios-deploy -I -m -b ${filename_app}
		fi
	fi

	if [ ${platform} == ${linux_platform} ]; then
		filename="${platform_folder}/${file_prefix_name}_${mode}_linux/${title_no_space}.x86_64"

		echo "Start Linux build: $filename"
		./$filename
	fi

	if [ ${platform} == ${macos_platform} ]; then
		filename="${platform_folder}/${file_prefix_name}_${mode}_macos.app"

		if [ ${mode} == "debug" ]; then
			filename="${platform_folder}/${title}.app/Contents/MacOS/${title_no_space}"
		fi

		echo "Start MacOS build: $filename"
		open $filename ; exit;
	fi

	if [ ${platform} == ${windows_platform} ]; then
		filename="${platform_folder}/${file_prefix_name}_${mode}_windows/${title_no_space}.exe"

		echo "Start Windows build: $filename"
		./$filename
	fi
}


clean_build_settings() {
	rm -f ${version_settings_filename}
	rm -f settings_android_debug_temp.ini
}


get_all_ios_devices() {
	# Try to get all available iOS devices using devicectl with retry logic
	local max_attempts=3
	local attempt=1

	while [ $attempt -le $max_attempts ]; do
		local device_list=$(xcrun devicectl list devices 2>/dev/null)
		local devicectl_exit_code=$?

		# Debug info for failed attempts
		if [ $devicectl_exit_code -ne 0 ] || [ -z "$device_list" ]; then
			echo "Attempt $attempt failed - devicectl exit code: $devicectl_exit_code, output length: ${#device_list}" >&2
		fi

		if [ $devicectl_exit_code -eq 0 ] && [ -n "$device_list" ]; then
			# Parse the device table and collect all available devices
			# Skip the header lines and process each device line
			local devices_info=""
			local temp_file=$(mktemp)

			echo "$device_list" | tail -n +3 | while IFS= read -r line; do
				# Skip empty lines and separator lines
				if [[ -z "$line" || "$line" =~ ^[[:space:]]*-+[[:space:]]*$ ]]; then
					continue
				fi

				# Extract UUID pattern from the line (this is the device identifier)
				local identifier=$(echo "$line" | grep -o "[0-9A-Fa-f]\{8\}-[0-9A-Fa-f]\{4\}-[0-9A-Fa-f]\{4\}-[0-9A-Fa-f]\{4\}-[0-9A-Fa-f]\{12\}")

				# Check if the line contains "available", "connected", or "available (paired)" but not "unavailable"
				if [[ "$line" =~ (available|connected) ]] && [[ ! "$line" =~ unavailable ]]; then
					if [ -n "$identifier" ]; then
						# Extract device name (everything before the identifier)
						local device_name=$(echo "$line" | sed "s/${identifier}.*//g" | sed 's/[[:space:]]*$//')
						echo "${identifier}|${device_name}|${line}" >> "$temp_file"
					fi
				fi
			done

			# Read the results from temp file and output them
			if [ -s "$temp_file" ]; then
				cat "$temp_file"
				rm -f "$temp_file"
				return 0
			fi
			rm -f "$temp_file"
		fi

		# Only show retry message if not the last attempt
		if [ $attempt -lt $max_attempts ]; then
			echo "No available iOS devices found on attempt $attempt, retrying in 5 seconds..." >&2
			sleep 5
		fi
		attempt=$((attempt + 1))
	done

	# If we get here, no available devices were found after all attempts
	echo "No available iOS devices could be found after $max_attempts attempts" >&2
	echo "Debug info - devicectl output:" >&2
	xcrun devicectl list devices >&2 2>&1
	return 1
}

select_ios_device() {
	# Get all available devices
	local devices_output=$(get_all_ios_devices)
	local get_devices_exit_code=$?

	if [ $get_devices_exit_code -ne 0 ]; then
		echo -e "\x1B[31m[ERROR]: Failed to get iOS devices\x1B[0m" >&2
		return 1
	fi

	# Convert output to array
	local devices=()
	local device_ids=()
	local device_names=()

	while IFS='|' read -r device_id device_name full_line; do
		if [ -n "$device_id" ]; then
			devices+=("$full_line")
			device_ids+=("$device_id")
			device_names+=("$device_name")
		fi
	done <<< "$devices_output"

	# Check how many devices we found
	local device_count=${#devices[@]}

	if [ $device_count -eq 0 ]; then
		echo -e "\x1B[31m[ERROR]: No available iOS devices found\x1B[0m" >&2
		return 1
	elif [ $device_count -eq 1 ]; then
		# Only one device, use it automatically
		echo "Found one iOS device: ${device_names[0]}" >&2
		echo "${device_ids[0]}"
		return 0
	else
		# Multiple devices found - check for saved preference
		local preferred_device_id=""
		local preferred_device_name=""
		local preferred_device_index=-1

		if [ -f "$ios_device_preference_filename" ]; then
			preferred_device_id=$(cat "$ios_device_preference_filename" 2>/dev/null)

			# Check if the preferred device is still available
			for i in "${!device_ids[@]}"; do
				if [ "${device_ids[$i]}" == "$preferred_device_id" ]; then
					preferred_device_index=$i
					preferred_device_name="${device_names[$i]}"
					break
				fi
			done
		fi

		if [ $preferred_device_index -ge 0 ]; then
			# Preferred device is available, use it automatically
			echo "Using preferred device: ${preferred_device_name}" >&2
			echo "$preferred_device_id"
			return 0
		else
			# No valid preferred device, show full selection
			echo -e "\x1B[36mMultiple iOS devices found:\x1B[0m" >&2
			for i in "${!devices[@]}"; do
				echo "  $((i+1)). ${device_names[$i]} (${device_ids[$i]})" >&2
			done

			echo -n "Please select a device (1-$device_count): " >&2
			read -r selection

			# Validate selection
			if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le $device_count ]; then
				local selected_index=$((selection-1))
				save_ios_device_preference "${device_ids[$selected_index]}"
				echo "Selected device: ${device_names[$selected_index]}" >&2
				echo "${device_ids[$selected_index]}"
				return 0
			else
				echo -e "\x1B[31m[ERROR]: Invalid selection. Please enter a number between 1 and $device_count\x1B[0m" >&2
				return 1
			fi
		fi
	fi
}

save_ios_device_preference() {
	local device_id=$1
	if [ -n "$device_id" ]; then
		echo "$device_id" > "$ios_device_preference_filename"
		add_to_gitignore "$ios_device_preference_filename"
		echo "Device preference saved." >&2
	fi
}

launch_ios_app_with_console() {
	local device_id=$1
	local bundle_id=$2 # iOS bundle ID

	# Launch the app with console output
	echo "Launching app with console output..."
	echo "Command: xcrun devicectl device process launch --console --device ${device_id} ${bundle_id}"

	# This will block and show console output until the app is terminated
	xcrun devicectl device process launch --console --device ${device_id} ${bundle_id}

	return $?
}

upload_to_transporter() {
    local file_path=$1

    echo -e "\x1B[36mChecking Transporter credentials...\x1B[0m"
    echo "Username: ${transporter_username:-'(not set)'}"
    echo "Team ID: ${transporter_team_id:-'(not set)'}"
    echo "Password: ${transporter_password:+'(set)'}"
    if [ -z "$transporter_password" ]; then
        echo "Password: (not set)"
    fi

    if [ -z "$transporter_username" ] || [ -z "$transporter_password" ] || [ -z "$transporter_team_id" ]; then
        echo -e "\x1B[33mSkipping Transporter upload: credentials not configured\x1B[0m"
        echo "Required environment variables:"
        echo "  TRANSPORTER_USERNAME (Apple ID)"
        echo "  TRANSPORTER_PASSWORD (App-specific password)"
        echo "  TRANSPORTER_TEAM_ID (Team ID from App Store Connect)"
        echo "Add these to your ~/.zshrc file with:"
        echo "  export TRANSPORTER_USERNAME=\"your_apple_id@example.com\""
        echo "  export TRANSPORTER_PASSWORD=\"your_app_specific_password\""
        echo "  export TRANSPORTER_TEAM_ID=\"your_team_id\""
        return 0
    fi

    echo -e "\x1B[32mTransporter credentials found! Uploading to App Store Connect...\x1B[0m"
    echo "File: ${file_path}"
    echo "Apple ID: ${transporter_username}"
    echo "Team ID: ${transporter_team_id}"

    xcrun notarytool submit "${file_path}" \
        --apple-id "${transporter_username}" \
        --password "${transporter_password}" \
        --team-id "${transporter_team_id}" \
        --wait
}

zip_release_build() {
    local platform=$1
    local mode=$2
    local target_path=$3

    # Only zip release builds
    if [ "${mode}" != "release" ]; then
        return 0
    fi

    echo -e "\x1B[36mZipping release build: ${target_path}\x1B[0m"

    if [ ${platform} == ${macos_platform} ]; then
        # For Mac, zip the .app file
        local zip_filename="${platform_folder}/${file_prefix_name}_${mode}_macos.zip"
        echo "Creating zip archive for macOS: ${zip_filename}"

        # Navigate to the directory containing the .app file
        local current_dir=$(pwd)
        cd "${platform_folder}"

        # Get just the app name without the path
        local app_name=$(basename "${target_path}")

        # Zip the .app file
        zip -r "${file_prefix_name}_${mode}_macos.zip" "${app_name}" -x "*.DS_Store" -x "*/.*"

        # Return to original directory
        cd "${current_dir}"

        echo -e "\x1B[32mMacOS zip archive created: ${zip_filename}\x1B[0m"
    fi

    if [ ${platform} == ${windows_platform} ]; then
        # For Windows, zip all the contents inside the build folder
        local zip_filename="${target_path}/${file_prefix_name}_${mode}_windows.zip"
        echo "Creating zip archive for Windows: ${zip_filename}"

        # Navigate to inside the Windows build folder
        local current_dir=$(pwd)
        cd "${target_path}"

        # Zip all contents of the current directory
        zip -r "${file_prefix_name}_${mode}_windows.zip" ./* -x "*.zip"

        # Return to original directory
        cd "${current_dir}"

        echo -e "\x1B[32mWindows zip archive created: ${zip_filename}\x1B[0m"
    fi
}

# TODO: finish implementing and testing this.
upload_to_steam() {
    local platform=$1
    local mode=$2
    local target_path=$3

    # Only upload release builds to Steam
    if [ "${mode}" != "release" ]; then
        echo -e "\x1B[33mSkipping Steam upload: only release builds can be uploaded to Steam\x1B[0m"
        return 0
    fi

    # Determine which depot ID to use based on platform
    local depot_id="${steam_depot_id}"

    if [ ${platform} == ${windows_platform} ] && [ ! -z "$steam_depot_id_windows" ]; then
        depot_id="${steam_depot_id_windows}"
        echo -e "Using Windows-specific depot ID: \x1B[33m${depot_id}\x1B[0m"
    elif [ ${platform} == ${macos_platform} ] && [ ! -z "$steam_depot_id_macos" ]; then
        depot_id="${steam_depot_id_macos}"
        echo -e "Using macOS-specific depot ID: \x1B[33m${depot_id}\x1B[0m"
    fi

    # Check if we have the required Steam credentials
    if [ -z "$steam_app_id" ] || [ -z "$depot_id" ] || [ -z "$steam_username" ]; then
        echo -e "\x1B[33mSkipping Steam upload: credentials not configured\x1B[0m"
        echo "Required settings in settings_deployer:"
        echo "  steam_app_id"
        if [ ${platform} == ${windows_platform} ]; then
            echo "  steam_depot_id_windows (or steam_depot_id as fallback)"
        elif [ ${platform} == ${macos_platform} ]; then
            echo "  steam_depot_id_macos (or steam_depot_id as fallback)"
        else
            echo "  steam_depot_id"
        fi
        echo "  steam_username"
        return 0
    fi

    # If no VDF path is provided, create a basic one
    local vdf_path="${steam_vdf_path}"
    if [ -z "$vdf_path" ]; then
        local vdf_dir="${script_path}/steam_vdf"
        mkdir -p "$vdf_dir"

        # Create app build VDF
        local app_vdf="${vdf_dir}/app_${steam_app_id}.vdf"
        echo "Creating basic Steam app VDF at ${app_vdf}"

        # Start the app VDF content
        local app_vdf_content="\"appbuild\"
{
    \"appid\" \"${steam_app_id}\"
    \"desc\" \"${title} ${version} ${mode} build\"
    \"buildoutput\" \"${PWD}/steam_build_output/\"
    \"contentroot\" \"${version_folder}\"
    \"setlive\" \"\"
    \"preview\" \"1\"
    \"local\" \"\"
    \"depots\"
    {"

        # Add the depot entry for the current platform
        app_vdf_content+="
        \"${depot_id}\" \"${vdf_dir}/depot_${depot_id}.vdf\""

        app_vdf_content+="
    }
}"

        # Write the app VDF content to file
        echo "${app_vdf_content}" > "$app_vdf"

        # Create depot build VDF
        local depot_vdf="${vdf_dir}/depot_${depot_id}.vdf"
        echo "Creating basic Steam depot VDF at ${depot_vdf}"
        echo "\"DepotBuildConfig\"
{
    \"DepotID\" \"${depot_id}\"
    \"ContentRoot\" \"${version_folder}/${platform}\"
    \"FileMapping\"
    {
        \"LocalPath\" \"*\"
        \"DepotPath\" \".\"
        \"recursive\" \"1\"
    }
    \"FileExclusion\" \"*.pdb\"
}" > "$depot_vdf"

        vdf_path="$app_vdf"
    fi

    echo -e "\x1B[36mUploading to Steam: ${target_path}\x1B[0m"
    echo -e "App ID: \x1B[33m${steam_app_id}\x1B[0m"
    echo -e "Depot ID: \x1B[33m${depot_id}\x1B[0m"
    echo -e "VDF Path: \x1B[33m${vdf_path}\x1B[0m"

    # Determine which steamcmd to use based on OS
    local steamcmd_path="steamcmd"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if [ -f "/usr/local/bin/steamcmd" ]; then
            steamcmd_path="/usr/local/bin/steamcmd"
        elif [ -d "${HOME}/steamcmd" ]; then
            steamcmd_path="${HOME}/steamcmd/steamcmd.sh"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if [ -f "/usr/games/steamcmd" ]; then
            steamcmd_path="/usr/games/steamcmd"
        elif [ -d "${HOME}/steamcmd" ]; then
            steamcmd_path="${HOME}/steamcmd/steamcmd.sh"
        fi
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        # Windows with Git Bash or similar
        if [ -f "C:/steamcmd/steamcmd.exe" ]; then
            steamcmd_path="C:/steamcmd/steamcmd.exe"
        fi
    fi

    echo -e "Using SteamCMD: \x1B[33m${steamcmd_path}\x1B[0m"

    # Run SteamCMD to upload the build
    "$steamcmd_path" +login "${steam_username}" +run_app_build "${vdf_path}" +quit

    echo -e "\x1B[32mSteam upload process completed\x1B[0m"
    echo -e "\x1B[32mCheck your Steam Partner dashboard to verify the upload\x1B[0m"
}


### ARGS PARSING
arg=$1
is_build=false
is_deploy=false
is_android=false
is_ios=false
is_html=false
is_linux=false
is_macos=false
is_windows=false
is_resolve=true
is_android_instant=false
is_fast_debug=false
mode="debug"
settings_params=""
build_params=""
build_server=${build_server:-"https://build.defold.com"}

for (( i=0; i<${#arg}; i++ )); do
	a=${arg:$i:1}
	if [ $a == "b" ]; then
		is_build=true
	fi
	if [ $a == "d" ]; then
		is_deploy=true
	fi
	if [ $a == "r" ]; then
		mode="release"
	fi
	if [ $a == "a" ]; then
		is_android=true
	fi
	if [ $a == "i" ]; then
		is_ios=true
	fi
	if [ $a == "h" ]; then
		is_html=true
	fi
	if [ $a == "l" ]; then
		is_linux=true
	fi
	if [ $a == "w" ]; then
		is_windows=true
	fi
	if [ $a == "m" ]; then
		is_macos=true
	fi
done

shift
while [[ $# -gt 0 ]]
do
	key=$1

	case $key in
		--instant)
			is_android_instant=true
			mode="release"
			file_prefix_name+="_instant"
			shift
		;;
		--fast)
			is_fast_debug=true
			shift
		;;
		--no-resolve)
			is_resolve=false
			shift
		;;
		--settings)
			settings_params="${settings_params} --settings $2"
			shift
			shift
		;;
		--param)
			build_params="${build_params} $2"
			shift
			shift
		;;
		--headless)
			mode="headless"
			shift
		;;
		--steam)
			is_steam_upload=true
			shift
		;;
		--reset-ios-device)
			# This is handled in early argument parsing, just skip it here
			shift
		;;
		*) # Unknown option
			shift
		;;
	esac
done


### Create deployer additional info project settings
echo "[project]
version = ${version}
commit_sha = ${commit_sha}
build_date = ${build_date}" > ${version_settings_filename}

if $enable_incremental_android_version_code; then
	echo "
[ios]
bundle_version = ${commits_count}" >> ${version_settings_filename}
	echo "
[android]
version_code = ${commits_count}" >> ${version_settings_filename}
fi

settings_params="${settings_params} --settings ${version_settings_filename}"
add_to_gitignore $version_settings_filename


# Sound effect for start of deployer
afplay /System/Library/Sounds/Bottle.aiff
echo "[🚀] Starting deployer script..."

### Deployer run
if $is_steam_upload && [ "${mode}" != "release" ]; then
    echo -e "\x1B[33mWarning: Steam upload is enabled but will only work with release builds\x1B[0m"
    echo -e "\x1B[33mAdd 'r' to your command to enable release mode\x1B[0m"
fi

if $is_ios; then
	if $is_build; then
		echo -e "\nStart build on \x1B[36m${ios_platform}\x1B[0m"
		build ${ios_platform} ${mode}
	fi

	if $is_deploy; then
		echo "Start deploy project to device"
		deploy ${ios_platform} ${mode}
		echo "Waiting 3 seconds for device to settle after installation..."
		sleep 3
		run ${ios_platform} ${mode}
	fi
fi

if $is_android; then
	# For debug builds, create a temporary settings file to add .debug suffix to package name
	if [ "$mode" == "debug" ]; then
		echo -e "\nAdding .debug suffix to Android package name for debug build"
		# Create a temporary settings file to override the package name
		echo "[android]
package = ${bundle_id_android}.debug" > "settings_android_debug_temp.ini"
		settings_params="${settings_params} --settings settings_android_debug_temp.ini"
		# This file will be cleaned up when the script exits
	fi

	if ! $is_android_instant; then
		# Just build usual Android build
		if $is_build; then
			echo -e "\nStart build on \x1B[34m${android_platform}\x1B[0m"
			build ${android_platform} ${mode}
		fi

		if $is_deploy; then
			echo "Start deploy project to device"
			deploy ${android_platform} ${mode}
			run ${android_platform} ${mode}
		fi
	else
		# Build Android Instant APK
		echo -e "\nStart build on \x1B[34m${android_platform} Instant APK\x1B[0m"
		build ${android_platform} ${mode} "--settings ${android_instant_app_settings}"
		make_instant ${mode}

		if $is_deploy; then
			echo "No autodeploy for Instant APK builds..."
		fi
	fi
fi

if $is_html; then
	if $is_build; then
		echo -e "\nStart build on \x1B[33m${html_platform}\x1B[0m"
		build ${html_platform} ${mode}
	fi

	if $is_deploy; then
		deploy ${html_platform} ${mode}
	fi
fi

if $is_linux; then
	if $is_build; then
		echo -e "\nStart build on \x1B[33m${linux_platform}\x1B[0m"
		build ${linux_platform} ${mode}
	fi

	if $is_deploy; then
		run ${linux_platform} ${mode}
	fi
fi

if $is_macos; then
	if $is_build; then
		echo -e "\nStart build on \x1B[33m${macos_platform}\x1B[0m"
		build ${macos_platform} ${mode}
	fi

	if $is_deploy; then
		run ${macos_platform} ${mode}
	fi
fi

if $is_windows; then
	if $is_build; then
		echo -e "\nStart build on \x1B[33m${windows_platform}\x1B[0m"
		build ${windows_platform} ${mode}
	fi

	if $is_deploy; then
		run ${windows_platform} ${mode}
	fi
fi
