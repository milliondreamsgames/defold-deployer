# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Repository purpose
- Universal build and deploy script for Defold projects across Android, iOS, HTML5, Linux, macOS, and Windows.
- Primary entrypoint: deployer.sh. Configuration via settings_deployer (template provided).

Key constraints and prerequisites
- Run the deployer from a Defold project root containing game.project. This repository contains the deployer itself; for usage, execute it inside a target Defold project.
- Requirements (as needed for targets):
  - Java 11+ (for bob.jar)
  - Android: adb
  - iOS: ios-deploy, Xcode command line tools (xcrun devicectl)
  - HTML5: zip, Python 3 (http.server)
  - Steam uploads: steamcmd
- Settings file search order:
  - Global: settings_deployer next to deployer.sh
  - Project-specific: settings_deployer next to game.project (overrides global)

Common commands
- Setup
  - Copy settings_deployer.template to settings_deployer and edit for your environment (keystores, identities, bob settings, etc.).
  - Optional: symlink deployer.sh into PATH as deployer and chmod +x it.

- Build, deploy, run
  - Android (debug): ~/defold-deployer/deployer.sh abd
  - iOS (release, build+deploy+run): ~/defold-deployer/deployer.sh ibdr
  - Android + iOS (release builds): ~/defold-deployer/deployer.sh aibr
  - HTML5 (debug, build+run local server): ~/defold-deployer/deployer.sh hdb
  - macOS (debug, build+run): ~/defold-deployer/deployer.sh mbd
  - Windows (release build): ~/defold-deployer/deployer.sh wbr
  - Linux (headless, with extra settings): ~/defold-deployer/deployer.sh lbd --settings unit_test.txt --headless
  - Android Instant Apps (release): ~/defold-deployer/deployer.sh ab --instant
  - Faster Android iteration (debug): ~/defold-deployer/deployer.sh abd --fast
  - Upload release builds to Steam (Windows/macOS): append --steam to the corresponding release build command

- Dependency resolution
  - By default, dependencies are resolved; add --no-resolve to skip, or --resolve in older flows.

- Settings overrides per platform (examples)
  - --settings path/to/settings_android.ini, settings_ios, settings_html, etc.

- Transporter (iOS upload) credentials
  - Environment variables expected if using the upload helper: TRANSPORTER_USERNAME, TRANSPORTER_PASSWORD, TRANSPORTER_TEAM_ID.
  - These may be sourced from ~/.zshrc if not present in the environment.

Notes on tests and linting
- This repository does not define formal unit tests for deployer.sh. For UI/animation checks, ./test_spinner.sh demonstrates spinner output.
- No repo-configured linters are present.

High-level architecture and flow
- Entry script: deployer.sh
  - Argument parsing: compact flag set [a i h w l m r b d] + long options (e.g., --fast, --no-resolve/--resolve, --headless, --settings, --instant, --steam).
  - Settings loading: sources settings_deployer from the script directory (global) and from the current project directory (project-specific override).
  - Bob tooling management:
    - Calculates desired bob version and sha (from settings or latest channel) and downloads bob.jar into bob_folder if missing.
    - Resolves libraries via bob resolve (with recovery for corrupted caches).
  - Build orchestration (build function):
    - Per-platform branches prepare additional parameters (keystore, identities, live content, resource cache, platform settings, HTML report).
    - Invokes bob build/bundle with appropriate platform/architectures and mode (debug/release/headless).
    - Moves and normalizes artifacts into dist/bundle/{version-commit_count}/{platform}/ with consistent filenames per platform.
    - Optional zipping for release builds (macOS .app, Windows folder) and optional Steam upload.
    - Records build stats (CSV) when configured.
  - Deploy/run helpers:
    - Android: adb install, am start, logcat -s defold; debug builds auto-append .debug to package id.
    - iOS: prefers xcrun devicectl for install/launch with fallback to ios-deploy; remembers last used device in .ios_device_preference.
    - HTML5: launches local http.server and opens browser to the built path.
    - Desktop: opens the built app/binary per platform.
  - User feedback:
    - Enhanced console output with progress messages.
    - Optional audio cues (afplay) on macOS for tick/success/error; configurable via deployer_settings.json (sound_enabled).
  - Cleanup and robustness:
    - Traps interrupts and cleans background audio/tickers; cleans temp version settings.

- Support scripts and assets
  - progress.js: Node-based progress rendering helpers used by update_progress.sh (stats/progress lines beneath the spinner).
  - update_progress.sh: Shell wrapper to print progress while the main build runs.
  - test_spinner.sh: Local script to preview spinner/animation behavior.
  - steam_vdf_templates: VDF templates/support for Steam uploads; deployer can generate basic VDFs if none are provided.

Conventions and outputs
- Artifacts and directories
  - Build output folder: ./build/default_deployer
  - Distribution root: ./dist
  - Bundles: ./dist/bundle/{version-commit_count}/{platform}/
  - Filenames include {TitleNoSpace}_{Version}-{CommitCount}_{mode} and standardized extensions per platform (.apk, .aab, .ipa, .app, zipped bundles on release for desktop platforms).
- Versioning helpers (optional)
  - enable_incremental_version: replaces patch with git commit count.
  - enable_incremental_android_version_code: uses commit count as android.version_code.
- Live content
  - is_live_content adds -l yes to bob for publishing live content; liveupdate bundles are moved into platform_folder/liveupdate_content when present.

Project documentation
- README.md contains comprehensive usage and configuration details mirrored above.
- docs/CHANGELOG.md tracks notable deployer changes; update when modifying behavior/features.
