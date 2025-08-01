#!/bin/bash

# Progress updater for showing real-time statistics during deployment
# This script can be called periodically to update the progress display 
# while the magnificent rainbow spinner is running

# Function to update progress with file processing information
update_file_progress() {
    local current_file="$1"
    local total_files="$2" 
    local filename="$3"
    local bytes_per_second="$4"
    
    # Move cursor to progress line (assumes spinner is on line above)
    echo -e "\033[1B\033[K\c"  # Move down one line and clear it
    
    # Call the enhanced progress.js with file information
    node "$(dirname "$0")/progress.js" files "$current_file" "$total_files" "$filename" "$bytes_per_second"
    
    # Move cursor back up to spinner line
    echo -e "\033[1A\c"  # Move back up to spinner line
}

# Function to update general progress bar
update_progress() {
    local step="$1"
    local total="$2"
    local message="$3"
    local stats_json="$4"
    
    # Move to progress line
    echo -e "\033[1B\033[K\c" 
    
    # Show enhanced progress
    if [ -n "$stats_json" ]; then
        node "$(dirname "$0")/progress.js" show "$step" "$total" "$message" "$stats_json"
    else
        node "$(dirname "$0")/progress.js" show "$step" "$total" "$message"
    fi
    
    # Return to spinner line
    echo -e "\033[1A\c"
}

# Function to show a status message below the spinner
show_status() {
    local message="$1"
    local type="${2:-message}"  # message, success, error, warning
    
    # Move to status line
    echo -e "\033[1B\033[K\c"
    
    # Show status with appropriate formatting 
    node "$(dirname "$0")/progress.js" "$type" "$message"
    
    # Return to spinner line
    echo -e "\033[1A\c"
}

# Example usage demonstration
if [ "$1" == "demo" ]; then
    echo "🎯 Demonstrating progress updater alongside spinner..."
    echo ""
    
    # Start a background process that simulates file processing
    {
        for i in {1..20}; do
            filename="asset_${i}.png"
            speed=$((RANDOM % 2000000 + 500000))  # Random speed between 0.5-2.5 MB/s
            
            # Update file progress
            update_file_progress "$i" "20" "$filename" "$speed"
            
            sleep 0.3
        done
        
        # Final completion message
        show_status "All assets processed successfully!" "success"
    } &
    
    echo "Background progress updates running... (Press Ctrl+C to stop)"
    
    # Keep the demo running
    sleep 8
    
    echo ""
    echo "✨ Demo complete! This shows how progress can be updated in real-time ✨"
    echo "   while the magnificent spinner continues to sparkle above!"
fi

# Command line interface
if [ $# -eq 0 ]; then
    echo "Usage: $0 [command] [args...]"
    echo "Commands:"
    echo "  update_progress <step> <total> <message> [stats_json]"
    echo "  update_file_progress <current> <total> <filename> [bytes_per_sec]"  
    echo "  show_status <message> [type]"
    echo "  demo - Run demonstration"
    echo ""
    echo "This script is designed to work alongside the rainbow spinner"
    echo "to provide real-time progress updates during deployment operations."
else
    # Execute the requested command
    "$@"
fi
