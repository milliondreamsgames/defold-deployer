# Audio Features

The Defold Deployer includes comprehensive audio feedback to provide better user experience during build processes.

## Audio Events

### Startup Sound
- **File**: `/System/Library/Sounds/Bottle.aiff`
- **When**: When the deployer script starts
- **Purpose**: Confirms the script has begun execution

### Build Tick Sound  
- **File**: `/System/Library/Sounds/Morse.aiff`
- **When**: Every second during Bob build process
- **Purpose**: Provides audible feedback that build is progressing
- **Implementation**: Runs in background via `play_tick_sound()` function

### Success Sound
- **File**: `/System/Library/Sounds/Glass.aiff` 
- **When**: After successful operations (build completion, file operations)
- **Purpose**: Confirms successful completion

### Error Sound
- **File**: `/System/Library/Sounds/Basso.aiff`
- **When**: After failed operations  
- **Purpose**: Alerts user to failures requiring attention

## Technical Implementation

### Background Tick Sound
```bash
# Function runs in background during builds
play_tick_sound() {
    while true; do
        afplay /System/Library/Sounds/Morse.aiff
        sleep 1
    done
}

# Started before Bob build
play_tick_sound &
TICK_PID=$!

# Stopped after build completion or interruption
kill $TICK_PID 2>/dev/null
wait $TICK_PID 2>/dev/null
```

### Cleanup on Interruption
The script properly handles Ctrl+C interruption:
- Stops all background audio processes
- Prevents orphaned audio playback
- Uses PID tracking for reliable cleanup

### System Requirements
- **macOS**: Uses `afplay` command and system sounds
- **Alternative Systems**: Audio features will gracefully fail on non-macOS systems

## Customization

To modify audio behavior:

1. **Change Sounds**: Replace file paths in the deployer script:
   ```bash
   # Example: Use different tick sound
   afplay /System/Library/Sounds/Tink.aiff  # Instead of Morse.aiff
   ```

2. **Disable Audio**: Comment out `afplay` commands or redirect to `/dev/null`

3. **Add New Audio Events**: Follow the existing pattern:
   ```bash
   # Add audio feedback for specific events
   afplay /System/Library/Sounds/YourSound.aiff
   ```

## Available System Sounds (macOS)

Common system sounds you can use:
- `Basso.aiff` - Error/negative feedback
- `Blow.aiff` - Notification
- `Bottle.aiff` - Startup/positive  
- `Frog.aiff` - Attention
- `Funk.aiff` - Playful notification
- `Glass.aiff` - Success/completion
- `Hero.aiff` - Achievement  
- `Morse.aiff` - Rhythmic/progress indication
- `Ping.aiff` - Quick notification
- `Pop.aiff` - Light notification
- `Purr.aiff` - Gentle notification
- `Sosumi.aiff` - Classic Mac sound
- `Submarine.aiff` - Deep notification
- `Tink.aiff` - Light tick/progress

All system sounds are located in `/System/Library/Sounds/`
