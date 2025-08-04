# Changelog

All notable changes to the Defold Deployer project will be documented in this file.

## [Unreleased]

### Added
- **Enhanced Audio Feedback**: Added comprehensive audio feedback system during build processes
  - Tick sound (Morse.aiff) plays every second during Bob build process
  - Success sound (Glass.aiff) plays on successful operations
  - Error sound (Basso.aiff) plays on failed operations
  - Startup sound (Bottle.aiff) plays when deployer starts

- **Enhanced Progress Indicators**: Improved build progress visualization
  - Star collection mini-game during spinner animations with rare/legendary/mythic stars
  - Real-time collection statistics display
  - Dynamic rainbow trail effects with sparkle animations

- **Robust Cleanup System**: Added proper cleanup for background processes
  - `cleanup_tick_sound()` function ensures tick sounds stop on interruption
  - Enhanced `handle_interrupt()` function with comprehensive cleanup
  - Background tick sound PID tracking with `TICK_PID` global variable

### Changed
- **Build Process Audio**: Replaced Tink.aiff with Morse.aiff for tick sound during builds
- **Progress Display**: Simplified progress display system, disabled complex spinner animations for better performance
- **Error Handling**: Improved interrupt handling with proper cleanup of all background processes

### Technical Details
- Added `play_tick_sound()` function that runs in background during Bob builds
- Enhanced trap handling for Ctrl+C interruptions
- Improved audio feedback consistency across all build operations
- Added proper PID tracking and cleanup for background processes

### Files Modified
- `deployer.sh`: Enhanced with audio feedback, improved progress indicators, and robust cleanup system
