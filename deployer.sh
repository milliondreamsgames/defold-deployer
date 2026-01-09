#!/usr/bin/env bash
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
##  --texture-compression {true|false} - override texture compression setting (default: true for debug/release, false for headless)
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

### Exit on Cmd+C / Ctrl+C
handle_interrupt() {
	echo -e "\n\x1B[33m[INTERRUPTED]: Script cancelled by user\x1B[0m"
	exit 130
}

trap handle_interrupt INT
trap clean EXIT
# Remove set -e to prevent script exit on build failures
# We'll handle errors explicitly in the build functions

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
texture_compression_override=""

steam_app_id=""
steam_depot_id=""
steam_depot_id_windows=""
steam_depot_id_macos=""
steam_username=""
steam_vdf_path=""

### Settings loading
settings_filename="settings_deployer"
script_path="`dirname \"$0\"`"
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

# Use bob_folder as the base directory for dist, or ./dist if bob_folder is not set
if [ -n "${bob_folder}" ]; then
	# Remove trailing slash from bob_folder if present
	bob_base="${bob_folder%/}"
	dist_folder="${bob_base}/dist"
	echo -e "\x1B[36m[INFO]: Using dist folder based on bob_folder: ${dist_folder}\x1B[0m"
else
	dist_folder="./dist"
fi

bundle_folder="${dist_folder}/bundle"
commit_sha="unknown"
commits_count=0
is_git=false
is_cache_using=false

if git rev-parse --git-dir >/dev/null 2>&1; then
	commit_sha=`git rev-parse --verify HEAD`
	commits_count=`git rev-list --all --count`
	is_git=true
fi


### Runtime
is_build_success=false
is_build_started=false
build_time=false

# Platform-specific build success tracking
declare -A platform_build_success
overall_build_success=true

### Game project settings for deployer script
title=$(less game.project | grep "^title = " | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')
version=$(less game.project | grep "^version = " | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')
version=${version:='0.0.0'}
title_no_space=$(echo -e "${title}" | tr -cd '[:alnum:]') # removes spaces, hyphens and special characters
bundle_id_android=$(less game.project | grep "^package = " | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')
bundle_id_ios=$(less game.project | grep "^bundle_identifier = " | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')

### Determine version suffix for folder naming
# Priority: commits_count (if incremental) > hard_coded_bundle_version_code > bundle_version from game.project
if $enable_incremental_android_version_code; then
	version_suffix="$commits_count"
	echo -e "\x1B[36m[INFO]: Using git commits_count for folder naming: ${version_suffix}\x1B[0m"
elif [ -n "$hard_coded_bundle_version_code" ]; then
	version_suffix="$hard_coded_bundle_version_code"
	echo -e "\x1B[36m[INFO]: Using hard_coded_bundle_version_code for folder naming: ${version_suffix}\x1B[0m"
else
	# Extract bundle_version from game.project (iOS uses this field)
	game_project_bundle_version=$(grep "^bundle_version = " game.project | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//' | head -1)
	# Fallback to commits_count if not found in game.project
	version_suffix="${game_project_bundle_version:-$commits_count}"
	echo -e "\x1B[36m[INFO]: Using bundle_version from game.project for folder naming: ${version_suffix}\x1B[0m"
fi

### Override last version number with commits count
if $enable_incremental_version; then
	version="${version%.*}.$commits_count"
fi

file_prefix_name="${title_no_space}_${version}-${version_suffix}"
version_folder="${bundle_folder}/${version}-${version_suffix}"
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

echo -e "Using Bob version \x1B[35m${bob_version}\x1B[0m SHA: \x1B[35m${bob_sha}\x1B[0m"

bob_path="${bob_folder}/bob${bob_version}.jar"
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
		mkdir -p "$(dirname "$build_stats_report_file")"
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

	# Determine texture compression setting
	local use_texture_compression=""
	if [ -n "$texture_compression_override" ]; then
		use_texture_compression="$texture_compression_override"
	elif [ ${mode} == "debug" ] || [ ${mode} == "release" ]; then
		use_texture_compression="true"
	else
		use_texture_compression="false"
	fi

	if [ ${mode} == "debug" ]; then
		echo -e "\nBuild without distclean. Compression: ${use_texture_compression}, Debug mode"
		args+=" --texture-compression ${use_texture_compression} build bundle"
	fi

	if [ ${mode} == "release" ]; then
		echo -e "\nBuild with distclean. Compression: ${use_texture_compression}, Release mode"
		args+=" --texture-compression ${use_texture_compression} build bundle distclean"
	fi

	if [ ${mode} == "headless" ]; then
		echo -e "\nBuild with distclean. Compression: ${use_texture_compression}, Headless mode"
		args+=" --texture-compression ${use_texture_compression} build bundle distclean"
	fi

    start_build_time=`date +%s`

    echo -e "Build command: ${args}"
    echo "[🔨] Building project with Bob..."
    echo "\n=== BUILD OUTPUT ==="

    ${args}
    local build_exit_code=$?

	echo "\n=== END BUILD OUTPUT ==="

	if [ $build_exit_code -eq 0 ]; then
		echo "[✅] Build process completed successfully"
	else
		echo "[❌] Build process FAILED with exit code: $build_exit_code"
		return $build_exit_code
	fi

	build_time=$((`date +%s`-start_build_time))
	echo -e "Build time: $build_time seconds\n"
	return 0
}


build() {
	if [ -f ./${pre_build_script} ]; then
		echo "Run pre-build script: $pre_build_script"
		source ./$pre_build_script
	fi

	#clean first
	if [ "$skip_cache_cleanup" != "true" ]; then
		rm -f -r ./.deployer_cache
	fi
	rm -f -r ./build

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

		if bob ${mode} --platform ${platform} --bundle-format apk,aab --keystore ${android_keystore} \
			--keystore-pass ${android_keystore_password} \
			--build-server ${build_server} ${additional_params}; then
			echo "Bob build completed successfully for Android"

			target_path="${platform_folder}/${filename}.apk"
			if [ -f "${line}.apk" ]; then
				mv "${line}.apk" ${target_path}
				echo "Moved APK to: ${target_path}"
				is_build_success=true
			else
				echo "Warning: APK file not found at ${line}.apk"
			fi

			rm -f "${platform_folder}/${filename}.aab"
			if [ -f "${line}.aab" ]; then
				mv "${line}.aab" "${platform_folder}/${filename}.aab"
				echo "Moved AAB to: ${platform_folder}/${filename}.aab"
			else
				echo "Warning: AAB file not found at ${line}.aab"
			fi
		else
			echo "Bob build failed for Android"
			is_build_success=false
		fi
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

		# Add iOS signing params only if set
		ios_signing_params=""
		if [ ! -z "$ident" ]; then
			ios_signing_params="--identity ${ident}"
		fi
		if [ ! -z "$prov" ]; then
			ios_signing_params="${ios_signing_params} --mobileprovisioning ${prov}"
		fi

		if bob ${mode} --platform ${platform} --architectures arm64-ios ${ios_signing_params} \
			--build-server ${build_server} ${additional_params}; then
			echo "Bob build completed successfully for iOS"

			# Debug: Show what files were actually created
			echo "Checking for build artifacts in ${dist_folder}..."
			ls -la "${dist_folder}" || echo "dist folder not found"
			echo "Looking for iOS artifacts with pattern: ${line}.*"
			find "${dist_folder}" -name "${title}*" -type f 2/dev/null || echo "No iOS artifacts found matching ${title}"

			target_path="${platform_folder}/${filename}.ipa"
			rm -rf ${target_path}

			# Try to find and move the .ipa file
			if [ -f "${line}.ipa" ]; then
				echo "Found .ipa file: ${line}.ipa"
				mv "${line}.ipa" ${target_path}
				echo "Moved IPA to: ${target_path}"
				is_build_success=true
			else
				echo "Expected .ipa file not found at: ${line}.ipa"
				# Try to find any .ipa file in the dist folder
				ipa_file=$(find "${dist_folder}" -name "*.ipa" -type f | head -1)
				if [ -n "$ipa_file" ]; then
					echo "Found alternative .ipa file: $ipa_file"
					mv "$ipa_file" ${target_path}
					echo "Moved alternative IPA to: ${target_path}"
					is_build_success=true
				else
					echo "No .ipa file found in ${dist_folder}"
				fi
			fi

			rm -rf "${platform_folder}/${filename}.app"

			# Try to find and move the .app file
			if [ -d "${line}.app" ]; then
				echo "Found .app bundle: ${line}.app"
				mv "${line}.app" "${platform_folder}/${filename}.app"
				echo "Moved APP to: ${platform_folder}/${filename}.app"
			else
				echo "Expected .app bundle not found at: ${line}.app"
				# Try to find any .app bundle in the dist folder
				app_bundle=$(find "${dist_folder}" -name "*.app" -type d | head -1)
				if [ -n "$app_bundle" ]; then
					echo "Found alternative .app bundle: $app_bundle"
					mv "$app_bundle" "${platform_folder}/${filename}.app"
					echo "Moved alternative APP to: ${platform_folder}/${filename}.app"
				else
					echo "No .app bundle found in ${dist_folder}"
				fi
			fi
		else
			echo "Bob build failed for iOS"
			is_build_success=false
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

target_path="${platform_folder}/html_${filename}.zip"

		rm -rf "${platform_folder}/${filename}_html"
		rm -f "${target_path}"
		mv "${line}" "${platform_folder}/${filename}_html"

		previous_folder=`pwd`
		cd "${platform_folder}"
	zip "html_${filename}.zip" -r "${filename}_html" && is_build_success=true
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
		# Track per-platform build success
		platform_build_success["${platform}"]="true"
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
		# Track per-platform build failure
		platform_build_success["${platform}"]="false"
		overall_build_success=false
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
	fi

	if [ ${platform} == ${html_platform} ]; then
		filename="${platform_folder}/${file_prefix_name}_${mode}_html/"
		echo "Start python server ${filename:1}"
		echo "[📝] Web server starting at: http://localhost:8000${filename:1}"

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
local zip_filename="${platform_folder}/macos_${file_prefix_name}_${mode}.zip"
        echo "Creating zip archive for macOS: ${zip_filename}"

        # Navigate to the directory containing the .app file
        local current_dir=$(pwd)
        cd "${platform_folder}"

        # Get just the app name without the path
        local app_name=$(basename "${target_path}")

        # Zip the .app file
        zip -r "macos_${file_prefix_name}_${mode}.zip" "${app_name}" -x "*.DS_Store" -x "*/.*"

        # Return to original directory
        cd "${current_dir}"

        echo -e "\x1B[32mMacOS zip archive created: ${zip_filename}\x1B[0m"
    fi

    if [ ${platform} == ${windows_platform} ]; then
        # For Windows, zip all the contents inside the build folder
local zip_filename="${target_path}/windows_${file_prefix_name}_${mode}.zip"
        echo "Creating zip archive for Windows: ${zip_filename}"

        # Navigate to inside the Windows build folder
        local current_dir=$(pwd)
        cd "${target_path}"

        # Zip all contents of the current directory
        zip -r "windows_${file_prefix_name}_${mode}.zip" ./* -x "*.zip"

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
		--texture-compression)
			texture_compression_override="$2"
			shift
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

### Validate hard_coded_bundle_version_code setting
if [ -n "$hard_coded_bundle_version_code" ]; then
	# Check if it's a positive integer
	if ! [[ "$hard_coded_bundle_version_code" =~ ^[0-9]+$ ]]; then
		echo -e "\x1B[31m[ERROR]: hard_coded_bundle_version_code must be a positive integer, got: '${hard_coded_bundle_version_code}'\x1B[0m"
		exit 1
	fi

	# Warn if both incremental mode and hard-coded value are set
	if $enable_incremental_android_version_code; then
		echo -e "\x1B[33m[WARNING]: Both enable_incremental_android_version_code and hard_coded_bundle_version_code are set.\x1B[0m"
		echo -e "\x1B[33m[WARNING]: Incremental mode takes precedence - hard_coded_bundle_version_code will be ignored.\x1B[0m"
	fi
fi

### Create deployer additional info project settings
echo "[project]
version = ${version}
commit_sha = ${commit_sha}
build_date = ${build_date}" > ${version_settings_filename}

echo -e "\x1B[36m[DEBUG]: enable_incremental_android_version_code = '${enable_incremental_android_version_code}'\x1B[0m"
if $enable_incremental_android_version_code; then
	echo -e "\x1B[33m[DEBUG]: Writing version_code override (commits_count = ${commits_count})\x1B[0m"
	echo "
[ios]
bundle_version = ${commits_count}" >> ${version_settings_filename}
	echo "
[android]
version_code = ${commits_count}" >> ${version_settings_filename}
elif [ -n "$hard_coded_bundle_version_code" ]; then
	echo -e "\x1B[33m[DEBUG]: Writing hard-coded version_code override (hard_coded_bundle_version_code = ${hard_coded_bundle_version_code})\x1B[0m"
	echo "
[ios]
bundle_version = ${hard_coded_bundle_version_code}" >> ${version_settings_filename}
	echo "
[android]
version_code = ${hard_coded_bundle_version_code}" >> ${version_settings_filename}
else
	echo -e "\x1B[32m[DEBUG]: Skipping version_code override - will use game.project values\x1B[0m"
fi

settings_params="${settings_params} --settings ${version_settings_filename}"
add_to_gitignore $version_settings_filename


echo "[🚀] Starting deployer script..."

### Deployer run
if $is_steam_upload && [ "${mode}" != "release" ]; then
    echo -e "\x1B[33mWarning: Steam upload is enabled but will only work with release builds\x1B[0m"
    echo -e "\x1B[33mAdd 'r' to your command to enable release mode\x1B[0m"
fi

# Step 1: Build all requested platforms first
echo -e "\n=== BUILD PHASE ==="

# For debug builds, create a temporary settings file to add .debug suffix to package name
if $is_android && [ "$mode" == "debug" ]; then
	echo -e "\nAdding .debug suffix to Android package name for debug build"
	# Create a temporary settings file to override the package name
	echo "[android]
package = ${bundle_id_android}.debug" > "settings_android_debug_temp.ini"
	settings_params="${settings_params} --settings settings_android_debug_temp.ini"
	# This file will be cleaned up when the script exits
fi

if $is_build; then
	if $is_ios; then
		echo -e "\nStart build on \x1B[36m${ios_platform}\x1B[0m"
		build ${ios_platform} ${mode}
	fi

	if $is_android; then
		if ! $is_android_instant; then
			# Just build usual Android build
			echo -e "\nStart build on \x1B[34m${android_platform}\x1B[0m"
			build ${android_platform} ${mode}
		else
			# Build Android Instant APK
			echo -e "\nStart build on \x1B[34m${android_platform} Instant APK\x1B[0m"
			build ${android_platform} ${mode} "--settings ${android_instant_app_settings}"
			make_instant ${mode}
		fi
	fi

	if $is_html; then
		echo -e "\nStart build on \x1B[33m${html_platform}\x1B[0m"
		build ${html_platform} ${mode}
	fi

	if $is_linux; then
		echo -e "\nStart build on \x1B[33m${linux_platform}\x1B[0m"
		build ${linux_platform} ${mode}
	fi

	if $is_macos; then
		echo -e "\nStart build on \x1B[33m${macos_platform}\x1B[0m"
		build ${macos_platform} ${mode}
	fi

	if $is_windows; then
		echo -e "\nStart build on \x1B[33m${windows_platform}\x1B[0m"
		build ${windows_platform} ${mode}
	fi

	# Show build summary
	echo -e "\n=== BUILD SUMMARY ==="
	if $overall_build_success; then
		echo -e "\x1B[32m✅ All builds completed successfully!\x1B[0m"
	else
		echo -e "\x1B[31m❌ Some builds failed:\x1B[0m"
		for platform in "${!platform_build_success[@]}"; do
			if [ "${platform_build_success[$platform]}" == "false" ]; then
				echo -e "\x1B[31m  - $platform: FAILED\x1B[0m"
			else
				echo -e "\x1B[32m  - $platform: SUCCESS\x1B[0m"
			fi
		done
	fi
fi

# Step 2: Deploy/run only for successfully built platforms
if $is_deploy; then
	echo -e "\n=== DEPLOY PHASE ==="
	
	if $is_ios; then
		if [ "${platform_build_success[${ios_platform}]}" == "true" ] || ! $is_build; then
			echo "Start deploy iOS to device"
			deploy ${ios_platform} ${mode}
			echo "Waiting 3 seconds for device to settle after installation..."
			sleep 3
			run ${ios_platform} ${mode}
		else
			echo -e "\x1B[33m[SKIP]: iOS deployment skipped due to build failure\x1B[0m"
		fi
	fi

	if $is_android; then
		if [ "${platform_build_success[${android_platform}]}" == "true" ] || ! $is_build; then
			if ! $is_android_instant; then
				echo "Start deploy Android to device"
				deploy ${android_platform} ${mode}
				run ${android_platform} ${mode}
			else
				echo "No autodeploy for Instant APK builds..."
			fi
		else
			echo -e "\x1B[33m[SKIP]: Android deployment skipped due to build failure\x1B[0m"
		fi
	fi

	if $is_html; then
		if [ "${platform_build_success[${html_platform}]}" == "true" ] || ! $is_build; then
			deploy ${html_platform} ${mode}
		else
			echo -e "\x1B[33m[SKIP]: HTML5 deployment skipped due to build failure\x1B[0m"
		fi
	fi

	if $is_linux; then
		if [ "${platform_build_success[${linux_platform}]}" == "true" ] || ! $is_build; then
			run ${linux_platform} ${mode}
		else
			echo -e "\x1B[33m[SKIP]: Linux run skipped due to build failure\x1B[0m"
		fi
	fi

	if $is_macos; then
		if [ "${platform_build_success[${macos_platform}]}" == "true" ] || ! $is_build; then
			run ${macos_platform} ${mode}
		else
			echo -e "\x1B[33m[SKIP]: MacOS run skipped due to build failure\x1B[0m"
		fi
	fi

	if $is_windows; then
		if [ "${platform_build_success[${windows_platform}]}" == "true" ] || ! $is_build; then
			run ${windows_platform} ${mode}
		else
			echo -e "\x1B[33m[SKIP]: Windows run skipped due to build failure\x1B[0m"
		fi
	fi
fi
