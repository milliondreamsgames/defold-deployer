#!/bin/bash

# Test spinner function copied from deployer.sh
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
    
    # Collection tracking
    declare -A collection
    collection["common"]=0
    collection["rare"]=0
    collection["legendary"]=0
    collection["mythic"]=0
    
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
            rare_chance=$(echo "scale=2; $rare_chance + 0.5" | bc 2>/dev/null || echo "$rare_chance")
            if (( collected_stars % 50 == 0 )); then
                legendary_chance=$(echo "scale=2; $legendary_chance + 0.25" | bc 2>/dev/null || echo "$legendary_chance")
            fi
            if (( collected_stars % 100 == 0 )); then
                mythic_chance=$(echo "scale=2; $mythic_chance + 0.05" | bc 2>/dev/null || echo "$mythic_chance")
            fi
        fi
        
        # Check for special star encounters
        local random_val=$((RANDOM % 10000))
        local special_star_found=""
        local special_star_type=""
        
        local mythic_threshold=$(echo "$mythic_chance * 100" | bc 2>/dev/null | cut -d. -f1 2>/dev/null || echo "0")
        local legendary_threshold=$(echo "$legendary_chance * 100" | bc 2>/dev/null | cut -d. -f1 2>/dev/null || echo "1")
        local rare_threshold=$(echo "$rare_chance * 100" | bc 2>/dev/null | cut -d. -f1 2>/dev/null || echo "5")
        
        if (( random_val < mythic_threshold )); then
            # Mythic star found!
            special_star_found="${mythic_stars[$((RANDOM % ${#mythic_stars[@]}))]}"
            special_star_type="mythic"
            ((collection["mythic"]++))
            ((special_stars_collected++))
        elif (( random_val < legendary_threshold )); then
            # Legendary star found!
            special_star_found="${legendary_stars[$((RANDOM % ${#legendary_stars[@]}))]}"
            special_star_type="legendary"
            ((collection["legendary"]++))
            ((special_stars_collected++))
        elif (( random_val < rare_threshold )); then
            # Rare star found!
            special_star_found="${rare_stars[$((RANDOM % ${#rare_stars[@]}))]}"
            special_star_type="rare"
            ((collection["rare"]++))
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
            if (( collection["rare"] > 0 )); then
                collection_display+=" 🌟${collection["rare"]}"
            fi
            if (( collection["legendary"] > 0 )); then
                collection_display+=" 🧚${collection["legendary"]}"
            fi
            if (( collection["mythic"] > 0 )); then
                collection_display+=" 🪐${collection["mythic"]}"
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

cleanup_spinner() {
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
        SPINNER_PID=""
        printf "\r\033[K"  # Clear spinner line
        tput cnorm  # Show cursor
    fi
}

# Cleanup on interrupt
trap 'cleanup_spinner; exit 130' INT

# Test the spinner function directly
echo "Testing sparkle spinner animation for 10 seconds..."
echo "You should see a colorful animated star trail with collection stats!"
echo "Press Ctrl+C to stop early"
echo ""

# Start spinner in background
spin &
SPINNER_PID=$!

# Let it run for 10 seconds
sleep 10

# Clean up
cleanup_spinner

echo -e "\n\nSpinner test complete! If you saw the animated stars, the spinner is working correctly."
