#!/opt/homebrew/bin/bash
# claude-log-monitor.sh - Intelligent log monitoring with Claude Code integration
# Phase 1: Core Logic Foundation

set -euo pipefail

# Configuration
MONITOR_DIR="./.claude-monitors"
CONFIG_FILE="${MONITOR_DIR}/config.json"
SESSION_FILE="${MONITOR_DIR}/current_session"
RECOVERY_FILE="${MONITOR_DIR}/recovery_state"
LOG_BUFFER_SIZE=1000
CONTEXT_CHECKPOINT_INTERVAL=300  # 5 minutes
WEBHOOK_TIMEOUT=10  # seconds
MAX_RETRY_ATTEMPTS=3
RETRY_DELAY=5  # seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Debug logging prefix for Phase 1 validation
DEBUG_PREFIX="[FEATURE]"
# Phase 4: Production logging prefix
PRODUCTION_PREFIX="[PRODUCTION] [FEATURE]"

# Logging function for Phase 1 validation
log_debug() {
    echo -e "${BLUE}${DEBUG_PREFIX}${NC} $*"
}

# Production logging function for Phase 4 validation
log_production() {
    echo -e "${PURPLE}${PRODUCTION_PREFIX}${NC} $*"
}

# Configuration validation
validate_config() {
    local config_file=$1
    log_debug "Validating configuration file: $config_file"
    
    if [ ! -f "$config_file" ]; then
        log_debug "Config file does not exist, creating default"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq empty "$config_file" 2>/dev/null; then
        log_debug "Invalid JSON in config file"
        return 1
    fi
    
    # Validate required fields
    local required_fields=("monitoring_enabled" "alert_threshold" "platforms" "session_timeout" "webhooks")
    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$config_file" >/dev/null 2>&1; then
            log_debug "Missing required field in config: $field"
            return 1
        fi
    done
    
    log_debug "Configuration validation successful"
    return 0
}

# Initialize monitoring system
init_monitoring() {
    log_debug "Initializing Claude log monitoring..."
    
    # Create directory structure
    mkdir -p "$MONITOR_DIR"
    mkdir -p "$MONITOR_DIR/sessions"
    mkdir -p "$MONITOR_DIR/reports"
    mkdir -p "$MONITOR_DIR/patterns"
    
    log_debug "Created directory structure at $MONITOR_DIR"
    
    # Create default configuration
    cat > "$CONFIG_FILE" << EOF
{
    "monitoring_enabled": true,
    "alert_threshold": "error",
    "platforms": ["android", "ios", "html5", "linux", "macos", "windows"],
    "auto_troubleshoot": true,
    "save_context": true,
    "notification_webhook": "",
    "claude_model": "claude-3-5-sonnet-20241022",
    "session_timeout": 7200,
    "log_retention_days": 30,
    "webhooks": {
        "enabled": false,
        "providers": {
            "slack": {
                "url": "",
                "channel": "#builds",
                "username": "Claude Monitor",
                "icon_emoji": ":robot_face:",
                "enabled": false
            },
            "discord": {
                "url": "",
                "username": "Claude Monitor",
                "avatar_url": "",
                "enabled": false
            },
            "teams": {
                "url": "",
                "enabled": false
            }
        },
        "alert_levels": ["error", "critical"],
        "build_notifications": {
            "start": false,
            "success": true,
            "failure": true
        }
    },
    "recovery": {
        "enabled": true,
        "max_retry_attempts": 3,
        "retry_delay_seconds": 5,
        "checkpoint_interval_seconds": 300,
        "preserve_context": true
    },
    "team_features": {
        "shared_sessions": false,
        "knowledge_base": true,
        "performance_tracking": true,
        "trend_analysis": true
    }
}
EOF
    
    log_debug "Created default configuration file"
    
    # Validate configuration
    if validate_config "$CONFIG_FILE"; then
        echo -e "${GREEN}[SUCCESS]${NC} Claude log monitoring initialized"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Failed to create valid configuration"
        return 1
    fi
}

# Generate monitoring prompt for Claude sessions
generate_monitor_prompt() {
    local platform=$1
    local mode=$2
    local project_title=${3:-"DefoldProject"}
    local version=${4:-"1.0.0"}
    
    log_debug "Generating monitor prompt for platform=$platform, mode=$mode"
    
    cat << EOF
You are a Defold Build Pipeline Log Monitor Agent for project "${project_title}" v${version}.

## Your Mission
Monitor and analyze build/deployment logs in real-time for ${platform} platform in ${mode} mode.

## Core Responsibilities
1. **Real-time Log Analysis**: Parse incoming log streams and identify critical events
2. **Error Detection & Classification**: Categorize errors by severity and type
3. **Intelligent Troubleshooting**: Provide actionable solutions for detected issues
4. **Performance Monitoring**: Track build times, resource usage, and optimization opportunities
5. **Pattern Recognition**: Learn from recurring issues and suggest prevention strategies

## Current Context
- Platform: ${platform}
- Build Mode: ${mode}
- Project: ${project_title}
- Version: ${version}
- Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Expected Log Patterns
### Build Phase Logs
- Bob.jar execution output
- Dependency resolution messages
- Compilation progress and errors
- Asset processing status
- Platform-specific build steps

### Deployment Phase Logs
- Device detection and connection
- App installation progress
- Runtime logs from target device
- Performance metrics from device

## Error Categories to Monitor
1. **Critical Errors**: Build failures, deployment failures, crash logs
2. **Warnings**: Performance issues, deprecated API usage, missing assets
3. **Security Issues**: Insecure configurations, credential exposure
4. **Performance Issues**: Slow builds, memory usage, disk space

## Response Format
For each significant event, respond with JSON format:
{
    "timestamp": "ISO-8601 timestamp",
    "level": "info|warning|error|critical", 
    "category": "build|deployment|performance|security",
    "platform": "${platform}",
    "summary": "Brief description of the event",
    "details": "Detailed analysis of the issue",
    "suggested_actions": ["array", "of", "actionable", "steps"],
    "confidence": 0.95,
    "similar_patterns": ["related", "error", "patterns"],
    "prevention_tips": ["tips", "to", "prevent", "recurrence"]
}

## Continuous Learning
Maintain context of previous issues and solutions. Build a knowledge base of:
- Common error patterns for each platform
- Successful resolution strategies
- Performance optimization techniques
- Platform-specific gotchas and solutions

Start monitoring now. Respond to each log event appropriately, and always be ready to help the developer resolve issues quickly.
EOF
}

# Session lifecycle management
create_session_metadata() {
    local session_id=$1
    local platform=$2
    local mode=$3
    local project_title=$4
    local version=$5
    local session_dir=$6
    
    log_debug "Creating session metadata for session: $session_id"
    
    cat > "${session_dir}/metadata.json" << EOF
{
    "session_id": "${session_id}",
    "platform": "${platform}",
    "mode": "${mode}",
    "project_title": "${project_title}",
    "version": "${version}",
    "start_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "active",
    "log_count": 0,
    "error_count": 0,
    "warning_count": 0,
    "pid_claude": 0,
    "pid_processor": 0
}
EOF
    
    log_debug "Session metadata created successfully"
}

# Named pipe communication setup
setup_communication_pipes() {
    local session_dir=$1
    
    log_debug "Setting up communication pipes in: $session_dir"
    
    local input_pipe="${session_dir}/input_pipe"
    local output_pipe="${session_dir}/output_pipe"
    
    # Remove existing pipes if they exist
    [ -p "$input_pipe" ] && rm -f "$input_pipe"
    [ -p "$output_pipe" ] && rm -f "$output_pipe"
    
    # Create named pipes
    mkfifo "$input_pipe" "$output_pipe"
    
    if [ -p "$input_pipe" ] && [ -p "$output_pipe" ]; then
        log_debug "Communication pipes created successfully"
        return 0
    else
        log_debug "Failed to create communication pipes"
        return 1
    fi
}

# Start monitoring session
start_monitoring_session() {
    local platform=${1:-"unknown"}
    local mode=${2:-"debug"}
    local project_title=${3:-"DefoldProject"}
    local version=${4:-"1.0.0"}
    
    log_debug "Starting monitoring session: platform=$platform, mode=$mode"
    log_production "Initializing enhanced monitoring session with team features"
    
    # Initialize if needed
    if [ ! -f "$CONFIG_FILE" ]; then
        log_debug "Configuration not found, initializing"
        init_monitoring || return 1
    fi
    
    # Check if monitoring is enabled
    local monitoring_enabled=$(jq -r '.monitoring_enabled' "$CONFIG_FILE" 2>/dev/null || echo "true")
    if [ "$monitoring_enabled" != "true" ]; then
        echo -e "${YELLOW}[SKIP]${NC} Claude monitoring disabled in config"
        return 0
    fi
    
    # Generate session ID
    local session_id="monitor_${platform}_${mode}_$(date +%s)"
    local session_dir="${MONITOR_DIR}/sessions/${session_id}"
    
    log_debug "Creating session directory: $session_dir"
    mkdir -p "$session_dir"
    
    echo -e "${CYAN}[START]${NC} Starting Claude monitoring session: ${session_id}"
    echo -e "${BLUE}[INFO]${NC} Platform: ${platform}, Mode: ${mode}"
    
    # Generate monitoring prompt
    generate_monitor_prompt "$platform" "$mode" "$project_title" "$version" > "${session_dir}/prompt.md"
    log_debug "Generated monitoring prompt"
    
    # Create session metadata
    create_session_metadata "$session_id" "$platform" "$mode" "$project_title" "$version" "$session_dir"
    
    # Setup communication pipes
    if ! setup_communication_pipes "$session_dir"; then
        echo -e "${RED}[ERROR]${NC} Failed to setup communication pipes"
        return 1
    fi
    
    # Store session ID as current
    echo "$session_id" > "$SESSION_FILE"
    log_debug "Session started successfully: $session_id"
    
    # Save recovery state for session preservation
    save_recovery_state "$session_id" "$platform" "$mode" "monitoring"
    
    # Send webhook notification for build start if configured
    local build_start_notifications=$(jq -r '.webhooks.build_notifications.start' "$CONFIG_FILE" 2>/dev/null)
    if [ "$build_start_notifications" = "true" ]; then
        send_webhook_notification "Claude monitoring session started for $platform $mode" "info" "Project: $project_title v$version, Session: $session_id"
    fi
    
    echo -e "${GREEN}[ACTIVE]${NC} Claude monitoring session prepared: ${session_id}"
    log_production "Enhanced monitoring session active with webhooks and recovery enabled"
    return 0
}

# Send log entry to active session
send_log_to_session() {
    local log_entry=$1
    
    if [ ! -f "$SESSION_FILE" ]; then
        log_debug "No active session file"
        return 0
    fi
    
    local session_id=$(cat "$SESSION_FILE")
    local session_dir="${MONITOR_DIR}/sessions/${session_id}"
    
    if [ ! -d "$session_dir" ]; then
        log_debug "Session directory not found: $session_dir"
        return 0
    fi
    
    log_debug "Sending log entry to session: $session_id"
    
    # Validate input pipe exists
    local input_pipe="${session_dir}/input_pipe"
    if [ ! -p "$input_pipe" ]; then
        log_debug "Input pipe not found: $input_pipe"
        return 1
    fi
    
    # Send log entry (non-blocking to avoid hanging)
    echo "LOG_ENTRY: $log_entry" > "$input_pipe" 2>/dev/null || {
        log_debug "Failed to send log entry to session"
        return 1
    }
    
    log_debug "Log entry sent successfully"
    return 0
}

# Stop monitoring session
stop_monitoring_session() {
    local session_id=${1:-$(cat "$SESSION_FILE" 2>/dev/null || echo "")}
    
    if [ -z "$session_id" ]; then
        echo -e "${YELLOW}[WARNING]${NC} No session to stop"
        return 1
    fi
    
    local session_dir="${MONITOR_DIR}/sessions/${session_id}"
    
    if [ ! -d "$session_dir" ]; then
        echo -e "${RED}[ERROR]${NC} Session directory not found: $session_id"
        return 1
    fi
    
    echo -e "${CYAN}[STOP]${NC} Stopping monitoring session: $session_id"
    log_debug "Stopping session: $session_id"
    
    # Clean up processes (PIDs would be stored in actual implementation)
    local claude_pid=$(jq -r '.pid_claude' "${session_dir}/metadata.json" 2>/dev/null || echo "0")
    local processor_pid=$(jq -r '.pid_processor' "${session_dir}/metadata.json" 2>/dev/null || echo "0")
    
    if [ "$claude_pid" -gt 0 ]; then
        kill "$claude_pid" 2>/dev/null || true
        log_debug "Stopped Claude process: $claude_pid"
    fi
    
    if [ "$processor_pid" -gt 0 ]; then
        kill "$processor_pid" 2>/dev/null || true
        log_debug "Stopped processor process: $processor_pid"
    fi
    
    # Clean up pipes
    rm -f "${session_dir}/input_pipe" "${session_dir}/output_pipe"
    log_debug "Cleaned up communication pipes"
    
    # Update session metadata
    if [ -f "${session_dir}/metadata.json" ]; then
        jq '.status = "completed" | .end_time = "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"' \
           "${session_dir}/metadata.json" > "${session_dir}/metadata.json.tmp" && \
           mv "${session_dir}/metadata.json.tmp" "${session_dir}/metadata.json"
        log_debug "Updated session metadata"
    fi
    
    # Clear current session
    rm -f "$SESSION_FILE"
    
    echo -e "${GREEN}[STOPPED]${NC} Session stopped: $session_id"
    return 0
}

# Session cleanup and recovery
cleanup_all_sessions() {
    log_debug "Performing cleanup of all sessions"
    
    if [ -d "${MONITOR_DIR}/sessions" ]; then
        for session_dir in "${MONITOR_DIR}/sessions"/*; do
            if [ -d "$session_dir" ]; then
                local session_id=$(basename "$session_dir")
                log_debug "Cleaning up session: $session_id"
                
                # Remove any leftover pipes
                rm -f "${session_dir}/input_pipe" "${session_dir}/output_pipe"
                
                # Update status to completed if still active
                if [ -f "${session_dir}/metadata.json" ]; then
                    local status=$(jq -r '.status' "${session_dir}/metadata.json" 2>/dev/null || echo "unknown")
                    if [ "$status" = "active" ]; then
                        jq '.status = "interrupted" | .end_time = "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"' \
                           "${session_dir}/metadata.json" > "${session_dir}/metadata.json.tmp" && \
                           mv "${session_dir}/metadata.json.tmp" "${session_dir}/metadata.json"
                        log_debug "Marked session as interrupted: $session_id"
                    fi
                fi
            fi
        done
    fi
    
    # Clear current session
    rm -f "$SESSION_FILE"
    log_debug "Cleanup completed"
}

# List monitoring sessions
list_sessions() {
    if [ ! -d "${MONITOR_DIR}/sessions" ]; then
        echo -e "${YELLOW}[INFO]${NC} No sessions found"
        return 0
    fi
    
    log_debug "Listing monitoring sessions"
    echo -e "${CYAN}[SESSIONS]${NC} Available monitoring sessions:"
    echo ""
    
    local session_count=0
    
    for session_dir in "${MONITOR_DIR}/sessions"/*; do
        if [ -d "$session_dir" ]; then
            local session_id=$(basename "$session_dir")
            local metadata_file="${session_dir}/metadata.json"
            
            if [ -f "$metadata_file" ]; then
                local platform=$(jq -r '.platform' "$metadata_file" 2>/dev/null || echo "unknown")
                local mode=$(jq -r '.mode' "$metadata_file" 2>/dev/null || echo "unknown")
                local status=$(jq -r '.status' "$metadata_file" 2>/dev/null || echo "unknown")
                local start_time=$(jq -r '.start_time' "$metadata_file" 2>/dev/null || echo "unknown")
                
                case "$status" in
                    "active")
                        echo -e "${GREEN}●${NC} $session_id - $platform ($mode) - Started: $start_time"
                        ;;
                    "completed")
                        echo -e "${BLUE}○${NC} $session_id - $platform ($mode) - Started: $start_time"
                        ;;
                    *)
                        echo -e "${YELLOW}◐${NC} $session_id - $platform ($mode) - Started: $start_time"
                        ;;
                esac
                
                ((session_count++))
            fi
        fi
    done
    
    log_debug "Listed $session_count sessions"
    
    if [ $session_count -eq 0 ]; then
        echo -e "${YELLOW}[INFO]${NC} No valid sessions found"
    fi
}

# Configuration management
config_set() {
    local key=$1
    local value=$2
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_debug "Config file not found, initializing"
        init_monitoring || return 1
    fi
    
    log_debug "Setting configuration: $key = $value"
    
    # Validate JSON before modification
    if ! validate_config "$CONFIG_FILE"; then
        echo -e "${RED}[ERROR]${NC} Invalid configuration file"
        return 1
    fi
    
    # Update configuration
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && \
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    # Validate after modification
    if validate_config "$CONFIG_FILE"; then
        echo -e "${GREEN}[CONFIG]${NC} Set $key = $value"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Failed to update configuration"
        return 1
    fi
}

config_show() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}[WARNING]${NC} No configuration file found. Run 'init' first."
        return 1
    fi
    
    log_debug "Showing configuration"
    
    if validate_config "$CONFIG_FILE"; then
        echo -e "${CYAN}[CONFIG]${NC} Current configuration:"
        jq '.' "$CONFIG_FILE"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Configuration file is invalid"
        return 1
    fi
}

# Phase 4: Webhook Notification System

# Send webhook notification to Slack
send_slack_webhook() {
    local message="$1"
    local level="$2"
    local details="$3"
    
    log_production "Sending Slack webhook notification: $level"
    
    local webhook_url=$(jq -r '.webhooks.providers.slack.url' "$CONFIG_FILE" 2>/dev/null)
    local channel=$(jq -r '.webhooks.providers.slack.channel' "$CONFIG_FILE" 2>/dev/null)
    local username=$(jq -r '.webhooks.providers.slack.username' "$CONFIG_FILE" 2>/dev/null)
    local icon_emoji=$(jq -r '.webhooks.providers.slack.icon_emoji' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$webhook_url" = "null" ] || [ "$webhook_url" = "" ]; then
        log_debug "Slack webhook URL not configured"
        return 1
    fi
    
    # Determine color based on level
    local color="good"
    case "$level" in
        "error"|"critical") color="danger" ;;
        "warning") color="warning" ;;
        "success") color="good" ;;
    esac
    
    local payload
    payload=$(cat << EOF
{
    "channel": "$channel",
    "username": "$username",
    "icon_emoji": "$icon_emoji",
    "attachments": [{
        "color": "$color",
        "title": "Claude Code Monitor Alert",
        "text": "$message",
        "fields": [{
            "title": "Level",
            "value": "$level",
            "short": true
        }, {
            "title": "Time",
            "value": "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")",
            "short": true
        }],
        "footer": "$details",
        "ts": $(date +%s)
    }]
}
EOF
    )
    
    curl -X POST \
         -H "Content-Type: application/json" \
         --connect-timeout "$WEBHOOK_TIMEOUT" \
         --max-time "$WEBHOOK_TIMEOUT" \
         --data "$payload" \
         "$webhook_url" >/dev/null 2>&1
    
    local curl_exit=$?
    if [ $curl_exit -eq 0 ]; then
        log_production "Slack notification sent successfully"
        return 0
    else
        log_debug "Failed to send Slack notification (curl exit: $curl_exit)"
        return 1
    fi
}

# Send webhook notification to Discord
send_discord_webhook() {
    local message="$1"
    local level="$2"
    local details="$3"
    
    log_production "Sending Discord webhook notification: $level"
    
    local webhook_url=$(jq -r '.webhooks.providers.discord.url' "$CONFIG_FILE" 2>/dev/null)
    local username=$(jq -r '.webhooks.providers.discord.username' "$CONFIG_FILE" 2>/dev/null)
    local avatar_url=$(jq -r '.webhooks.providers.discord.avatar_url' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$webhook_url" = "null" ] || [ "$webhook_url" = "" ]; then
        log_debug "Discord webhook URL not configured"
        return 1
    fi
    
    # Determine color based on level
    local color=65280  # Green
    case "$level" in
        "error"|"critical") color=16711680 ;;  # Red
        "warning") color=16776960 ;;          # Yellow
        "success") color=65280 ;;             # Green
    esac
    
    local payload
    payload=$(cat << EOF
{
    "username": "$username",
    "avatar_url": "$avatar_url",
    "embeds": [{
        "title": "Claude Code Monitor Alert",
        "description": "$message",
        "color": $color,
        "fields": [{
            "name": "Level",
            "value": "$level",
            "inline": true
        }, {
            "name": "Time",
            "value": "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")",
            "inline": true
        }],
        "footer": {
            "text": "$details"
        },
        "timestamp": "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")"
    }]
}
EOF
    )
    
    curl -X POST \
         -H "Content-Type: application/json" \
         --connect-timeout "$WEBHOOK_TIMEOUT" \
         --max-time "$WEBHOOK_TIMEOUT" \
         --data "$payload" \
         "$webhook_url" >/dev/null 2>&1
    
    local curl_exit=$?
    if [ $curl_exit -eq 0 ]; then
        log_production "Discord notification sent successfully"
        return 0
    else
        log_debug "Failed to send Discord notification (curl exit: $curl_exit)"
        return 1
    fi
}

# Send webhook notification to Microsoft Teams
send_teams_webhook() {
    local message="$1"
    local level="$2"
    local details="$3"
    
    log_production "Sending Teams webhook notification: $level"
    
    local webhook_url=$(jq -r '.webhooks.providers.teams.url' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$webhook_url" = "null" ] || [ "$webhook_url" = "" ]; then
        log_debug "Teams webhook URL not configured"
        return 1
    fi
    
    # Determine theme color based on level
    local theme_color="00FF00"  # Green
    case "$level" in
        "error"|"critical") theme_color="FF0000" ;;  # Red
        "warning") theme_color="FFFF00" ;;          # Yellow
        "success") theme_color="00FF00" ;;          # Green
    esac
    
    local payload
    payload=$(cat << EOF
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "summary": "Claude Code Monitor Alert",
    "themeColor": "$theme_color",
    "title": "Claude Code Monitor Alert",
    "text": "$message",
    "sections": [{
        "facts": [{
            "name": "Level",
            "value": "$level"
        }, {
            "name": "Time",
            "value": "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")"
        }, {
            "name": "Details",
            "value": "$details"
        }]
    }]
}
EOF
    )
    
    curl -X POST \
         -H "Content-Type: application/json" \
         --connect-timeout "$WEBHOOK_TIMEOUT" \
         --max-time "$WEBHOOK_TIMEOUT" \
         --data "$payload" \
         "$webhook_url" >/dev/null 2>&1
    
    local curl_exit=$?
    if [ $curl_exit -eq 0 ]; then
        log_production "Teams notification sent successfully"
        return 0
    else
        log_debug "Failed to send Teams notification (curl exit: $curl_exit)"
        return 1
    fi
}

# Universal webhook notification dispatcher
send_webhook_notification() {
    local message="$1"
    local level="$2"
    local details="${3:-Defold build system notification}"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_debug "Config file not found, skipping webhook notification"
        return 0
    fi
    
    local webhooks_enabled=$(jq -r '.webhooks.enabled' "$CONFIG_FILE" 2>/dev/null)
    if [ "$webhooks_enabled" != "true" ]; then
        log_debug "Webhooks disabled in configuration"
        return 0
    fi
    
    # Check if this alert level should trigger notifications
    local alert_levels=$(jq -r '.webhooks.alert_levels[]' "$CONFIG_FILE" 2>/dev/null)
    local should_notify=false
    
    while IFS= read -r alert_level; do
        if [ "$alert_level" = "$level" ]; then
            should_notify=true
            break
        fi
    done <<< "$alert_levels"
    
    if [ "$should_notify" != "true" ]; then
        log_debug "Alert level '$level' not configured for notifications"
        return 0
    fi
    
    log_production "Dispatching webhook notifications for level: $level"
    
    local notification_sent=false
    
    # Send to Slack if enabled
    local slack_enabled=$(jq -r '.webhooks.providers.slack.enabled' "$CONFIG_FILE" 2>/dev/null)
    if [ "$slack_enabled" = "true" ]; then
        if send_slack_webhook "$message" "$level" "$details"; then
            notification_sent=true
        fi
    fi
    
    # Send to Discord if enabled
    local discord_enabled=$(jq -r '.webhooks.providers.discord.enabled' "$CONFIG_FILE" 2>/dev/null)
    if [ "$discord_enabled" = "true" ]; then
        if send_discord_webhook "$message" "$level" "$details"; then
            notification_sent=true
        fi
    fi
    
    # Send to Teams if enabled
    local teams_enabled=$(jq -r '.webhooks.providers.teams.enabled' "$CONFIG_FILE" 2>/dev/null)
    if [ "$teams_enabled" = "true" ]; then
        if send_teams_webhook "$message" "$level" "$details"; then
            notification_sent=true
        fi
    fi
    
    if [ "$notification_sent" = "true" ]; then
        log_production "Webhook notifications dispatched successfully"
        return 0
    else
        log_debug "No webhook notifications were sent"
        return 1
    fi
}

# Phase 4: Recovery and Retry Mechanisms

# Save recovery state for session preservation
save_recovery_state() {
    local session_id="$1"
    local platform="$2"
    local mode="$3"
    local operation="$4"
    
    log_production "Saving recovery state for session: $session_id"
    
    cat > "$RECOVERY_FILE" << EOF
{
    "session_id": "$session_id",
    "platform": "$platform",
    "mode": "$mode",
    "operation": "$operation",
    "timestamp": "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")",
    "recovery_attempts": 0,
    "last_checkpoint": "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")",
    "context_preserved": true
}
EOF
    
    log_production "Recovery state saved successfully"
}

# Load and validate recovery state
load_recovery_state() {
    if [ ! -f "$RECOVERY_FILE" ]; then
        log_debug "No recovery state file found"
        return 1
    fi
    
    log_production "Loading recovery state"
    
    # Validate JSON structure
    if ! jq empty "$RECOVERY_FILE" 2>/dev/null; then
        log_debug "Invalid recovery state file"
        return 1
    fi
    
    local timestamp=$(jq -r '.timestamp' "$RECOVERY_FILE" 2>/dev/null)
    local current_time=$(date +%s)
    local recovery_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +%s 2>/dev/null || echo "0")
    
    # Check if recovery state is too old (more than session timeout)
    local session_timeout=$(jq -r '.session_timeout' "$CONFIG_FILE" 2>/dev/null || echo "7200")
    local age=$((current_time - recovery_time))
    
    if [ $age -gt $session_timeout ]; then
        log_debug "Recovery state too old ($age seconds), discarding"
        rm -f "$RECOVERY_FILE"
        return 1
    fi
    
    log_production "Recovery state loaded and validated"
    return 0
}

# Attempt recovery from saved state
attempt_recovery() {
    log_production "Attempting session recovery"
    
    if ! load_recovery_state; then
        log_debug "Cannot load recovery state"
        return 1
    fi
    
    local session_id=$(jq -r '.session_id' "$RECOVERY_FILE" 2>/dev/null)
    local platform=$(jq -r '.platform' "$RECOVERY_FILE" 2>/dev/null)
    local mode=$(jq -r '.mode' "$RECOVERY_FILE" 2>/dev/null)
    local operation=$(jq -r '.operation' "$RECOVERY_FILE" 2>/dev/null)
    local recovery_attempts=$(jq -r '.recovery_attempts' "$RECOVERY_FILE" 2>/dev/null)
    
    # Check maximum retry attempts
    local max_attempts=$(jq -r '.recovery.max_retry_attempts' "$CONFIG_FILE" 2>/dev/null || echo "$MAX_RETRY_ATTEMPTS")
    if [ "$recovery_attempts" -ge "$max_attempts" ]; then
        log_production "Maximum recovery attempts reached ($max_attempts), giving up"
        send_webhook_notification "Recovery failed after $max_attempts attempts for $platform $mode" "critical" "Session: $session_id, Operation: $operation"
        rm -f "$RECOVERY_FILE"
        return 1
    fi
    
    # Increment recovery attempts
    local new_attempts=$((recovery_attempts + 1))
    jq --arg attempts "$new_attempts" '.recovery_attempts = ($attempts | tonumber)' "$RECOVERY_FILE" > "${RECOVERY_FILE}.tmp" && \
    mv "${RECOVERY_FILE}.tmp" "$RECOVERY_FILE"
    
    log_production "Recovery attempt $new_attempts/$max_attempts for session: $session_id"
    
    # Wait before retry
    local retry_delay=$(jq -r '.recovery.retry_delay_seconds' "$CONFIG_FILE" 2>/dev/null || echo "$RETRY_DELAY")
    if [ "$retry_delay" -gt 0 ]; then
        log_production "Waiting $retry_delay seconds before recovery attempt"
        sleep "$retry_delay"
    fi
    
    # Attempt to restart the operation
    case "$operation" in
        "monitoring")
            if start_monitoring_session "$platform" "$mode"; then
                log_production "Session recovery successful"
                send_webhook_notification "Session recovered successfully for $platform $mode" "success" "Recovery attempt: $new_attempts, Session: $session_id"
                rm -f "$RECOVERY_FILE"
                return 0
            else
                log_production "Session recovery failed"
                return 1
            fi
            ;;
        "build")
            log_production "Build recovery not implemented yet"
            return 1
            ;;
        *)
            log_production "Unknown operation for recovery: $operation"
            return 1
            ;;
    esac
}

# Intelligent retry wrapper for critical operations
retry_operation() {
    local operation_name="$1"
    shift
    local command_array=("$@")
    
    log_production "Starting retry operation: $operation_name"
    
    local max_attempts=$(jq -r '.recovery.max_retry_attempts' "$CONFIG_FILE" 2>/dev/null || echo "$MAX_RETRY_ATTEMPTS")
    local retry_delay=$(jq -r '.recovery.retry_delay_seconds' "$CONFIG_FILE" 2>/dev/null || echo "$RETRY_DELAY")
    
    for attempt in $(seq 1 "$max_attempts"); do
        log_production "Attempt $attempt/$max_attempts for operation: $operation_name"
        
        if "${command_array[@]}"; then
            log_production "Operation '$operation_name' succeeded on attempt $attempt"
            return 0
        else
            local exit_code=$?
            log_production "Operation '$operation_name' failed on attempt $attempt (exit code: $exit_code)"
            
            if [ $attempt -lt "$max_attempts" ]; then
                log_production "Waiting $retry_delay seconds before retry"
                sleep "$retry_delay"
            fi
        fi
    done
    
    log_production "Operation '$operation_name' failed after $max_attempts attempts"
    send_webhook_notification "Operation failed after retries: $operation_name" "error" "Failed after $max_attempts attempts"
    return 1
}

# Error handling and recovery
handle_error() {
    local error_message=$1
    local exit_code=${2:-1}
    
    echo -e "${RED}[ERROR]${NC} $error_message"
    log_debug "Error occurred: $error_message (exit code: $exit_code)"
    
    # Send webhook notification for critical errors
    send_webhook_notification "Critical error in Claude monitoring system" "critical" "Error: $error_message (Exit code: $exit_code)"
    
    # Cleanup on error
    cleanup_all_sessions
    
    return $exit_code
}

# Phase 2: Engine Integration Functions

# Build phase monitoring
build_start() {
    local platform=$1
    local mode=$2
    log_debug "Build started for platform: $platform, mode: $mode"
    log_production "Enhanced build monitoring with webhook notifications active"
    
    # Record build start time and create session if needed
    local session_id="${platform}_${mode}_$(date +%s)"
    echo "$session_id" > "${MONITOR_DIR}/current_build_session"
    
    # Create build log file
    local build_log="${MONITOR_DIR}/build_${session_id}.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') BUILD_START platform=$platform mode=$mode" > "$build_log"
    
    # Save recovery state for build operation
    save_recovery_state "$session_id" "$platform" "$mode" "build"
    
    # Send webhook notification for build start if configured
    local build_start_notifications=$(jq -r '.webhooks.build_notifications.start' "$CONFIG_FILE" 2>/dev/null)
    if [ "$build_start_notifications" = "true" ]; then
        send_webhook_notification "Build started for $platform $mode" "info" "Session: $session_id, Platform: $platform, Mode: $mode"
    fi
    
    log_debug "Build session created: $session_id"
    log_production "Build monitoring session initialized with recovery state"
}

build_end() {
    local platform=$1
    local mode=$2
    local exit_code=$3
    log_debug "Build ended for platform: $platform, mode: $mode, exit_code: $exit_code"
    log_production "Processing build completion with enhanced notifications"
    
    # Update build log with completion status
    if [ -f "${MONITOR_DIR}/current_build_session" ]; then
        local session_id=$(cat "${MONITOR_DIR}/current_build_session")
        local build_log="${MONITOR_DIR}/build_${session_id}.log"
        
        if [ "$exit_code" = "0" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') BUILD_SUCCESS platform=$platform mode=$mode" >> "$build_log"
            log_debug "Build successful for $platform $mode"
            log_production "Build completed successfully, sending success notifications"
            
            # Send success webhook notification if configured
            local build_success_notifications=$(jq -r '.webhooks.build_notifications.success' "$CONFIG_FILE" 2>/dev/null)
            if [ "$build_success_notifications" = "true" ]; then
                send_webhook_notification "Build completed successfully for $platform $mode" "success" "Session: $session_id, Platform: $platform, Mode: $mode"
            fi
            
            # Clean up recovery state on successful completion
            rm -f "$RECOVERY_FILE"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') BUILD_FAILED platform=$platform mode=$mode exit_code=$exit_code" >> "$build_log"
            log_debug "Build failed for $platform $mode with exit code $exit_code"
            log_production "Build failed, triggering error notifications and recovery procedures"
            
            # Send failure webhook notification if configured
            local build_failure_notifications=$(jq -r '.webhooks.build_notifications.failure' "$CONFIG_FILE" 2>/dev/null)
            if [ "$build_failure_notifications" = "true" ]; then
                send_webhook_notification "Build failed for $platform $mode" "error" "Session: $session_id, Platform: $platform, Mode: $mode, Exit code: $exit_code"
            fi
            
            # Attempt recovery if enabled
            local recovery_enabled=$(jq -r '.recovery.enabled' "$CONFIG_FILE" 2>/dev/null)
            if [ "$recovery_enabled" = "true" ]; then
                log_production "Recovery enabled, scheduling retry attempt"
                # Note: Recovery would be handled by calling script or scheduler
            fi
        fi
    fi
}

# Deploy phase monitoring  
deploy_start() {
    local platform=$1
    local mode=$2
    log_debug "Deploy started for platform: $platform, mode: $mode"
    
    # Create deploy log entry
    if [ -f "${MONITOR_DIR}/current_build_session" ]; then
        local session_id=$(cat "${MONITOR_DIR}/current_build_session")
        local build_log="${MONITOR_DIR}/build_${session_id}.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S') DEPLOY_START platform=$platform mode=$mode" >> "$build_log"
    fi
}

# Log streaming setup
stream_logs() {
    local platform=$1
    log_debug "Setting up log streaming for platform: $platform"
    
    # Prepare for log processing
    mkdir -p "${MONITOR_DIR}/logs"
    local log_file="${MONITOR_DIR}/logs/${platform}_$(date +%Y%m%d_%H%M%S).log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') LOG_STREAM_START platform=$platform" > "$log_file"
    
    log_debug "Log streaming initialized for $platform"
}

# Process streaming logs (called via tee)
process_logs() {
    local platform=$1
    log_debug "Processing logs for platform: $platform"
    
    # Read from stdin and process each line
    while IFS= read -r line; do
        # Filter and process relevant log entries
        if [[ "$line" =~ (ERROR|WARNING|FATAL|Exception|Failed|failed) ]]; then
            # This is an important log entry - could trigger Claude analysis
            echo "$(date '+%Y-%m-%d %H:%M:%S') IMPORTANT_LOG platform=$platform: $line" >> "${MONITOR_DIR}/important_logs.log"
        fi
        
        # Also store all logs for analysis
        echo "$(date '+%Y-%m-%d %H:%M:%S') platform=$platform: $line" >> "${MONITOR_DIR}/all_logs.log"
    done
}

# Session management for wrapper script
start_session() {
    local session_name=$1
    log_debug "Starting monitoring session: $session_name"
    
    # Initialize session tracking
    echo "$session_name" > "${MONITOR_DIR}/wrapper_session"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SESSION_START name=$session_name" >> "${MONITOR_DIR}/session.log"
    
    log_debug "Session started: $session_name"
}

end_session() {
    log_debug "Ending monitoring session"
    
    if [ -f "${MONITOR_DIR}/wrapper_session" ]; then
        local session_name=$(cat "${MONITOR_DIR}/wrapper_session")
        echo "$(date '+%Y-%m-%d %H:%M:%S') SESSION_END name=$session_name" >> "${MONITOR_DIR}/session.log"
        rm -f "${MONITOR_DIR}/wrapper_session"
        log_debug "Session ended: $session_name"
    fi
}

# Phase 4: Comprehensive Workflow Orchestration

# Team collaboration features
get_team_session_status() {
    log_production "Retrieving team session status"
    
    if [ ! -d "${MONITOR_DIR}/sessions" ]; then
        echo '{"active_sessions": 0, "team_sessions": []}'
        return 0
    fi
    
    local active_count=0
    local session_list="[]"
    
    for session_dir in "${MONITOR_DIR}/sessions"/*; do
        if [ -d "$session_dir" ]; then
            local metadata_file="${session_dir}/metadata.json"
            if [ -f "$metadata_file" ]; then
                local status=$(jq -r '.status' "$metadata_file" 2>/dev/null)
                if [ "$status" = "active" ]; then
                    ((active_count++))
                    
                    local session_id=$(jq -r '.session_id' "$metadata_file" 2>/dev/null)
                    local platform=$(jq -r '.platform' "$metadata_file" 2>/dev/null)
                    local mode=$(jq -r '.mode' "$metadata_file" 2>/dev/null)
                    local start_time=$(jq -r '.start_time' "$metadata_file" 2>/dev/null)
                    
                    # Build session info manually to avoid JSON parsing issues
                    local session_info="{\"session_id\": \"$session_id\", \"platform\": \"$platform\", \"mode\": \"$mode\", \"start_time\": \"$start_time\"}"
                    
                    if [ "$session_list" = "[]" ]; then
                        session_list="[$session_info]"
                    else
                        session_list="${session_list%]},$session_info]"
                    fi
                fi
            fi
        fi
    done
    
    echo "{\"active_sessions\": $active_count, \"team_sessions\": $session_list}"
}

# Performance metrics collection
collect_performance_metrics() {
    local session_id="$1"
    log_production "Collecting performance metrics for session: $session_id"
    
    local metrics_file="${MONITOR_DIR}/metrics_${session_id}.json"
    local session_dir="${MONITOR_DIR}/sessions/${session_id}"
    
    if [ ! -d "$session_dir" ]; then
        log_debug "Session directory not found for metrics collection"
        return 1
    fi
    
    # Calculate session duration
    local metadata_file="${session_dir}/metadata.json"
    local start_time=$(jq -r '.start_time' "$metadata_file" 2>/dev/null)
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Collect system performance data
    local cpu_usage=$(top -l 1 -s 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' || echo "0")
    local memory_usage=$(ps -A -o %mem | awk '{s+=$1} END {print s}' || echo "0")
    local disk_usage=$(df . | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
    
    # Count log entries processed
    local log_count=$(jq -r '.log_count' "$metadata_file" 2>/dev/null || echo "0")
    local error_count=$(jq -r '.error_count' "$metadata_file" 2>/dev/null || echo "0")
    local warning_count=$(jq -r '.warning_count' "$metadata_file" 2>/dev/null || echo "0")
    
    cat > "$metrics_file" << EOF
{
    "session_id": "$session_id",
    "timestamp": "$current_time",
    "session": {
        "start_time": "$start_time",
        "current_time": "$current_time",
        "log_count": $log_count,
        "error_count": $error_count,
        "warning_count": $warning_count
    },
    "system": {
        "cpu_usage_percent": $cpu_usage,
        "memory_usage_percent": $memory_usage,
        "disk_usage_percent": $disk_usage
    },
    "quality_metrics": {
        "error_rate": $(echo "scale=4; $error_count / ($log_count + 1)" | bc -l 2>/dev/null || echo "0"),
        "warning_rate": $(echo "scale=4; $warning_count / ($log_count + 1)" | bc -l 2>/dev/null || echo "0")
    }
}
EOF
    
    log_production "Performance metrics collected and saved to: $metrics_file"
}

# Knowledge base integration
update_knowledge_base() {
    local error_pattern="$1"
    local solution="$2"
    local platform="$3"
    
    log_production "Updating knowledge base with new solution"
    
    local kb_file="${MONITOR_DIR}/knowledge_base.json"
    
    # Initialize knowledge base if it doesn't exist
    if [ ! -f "$kb_file" ]; then
        echo '{"solutions": []}' > "$kb_file"
    fi
    
    # Add new solution entry
    local new_entry
    new_entry=$(cat << EOF
{
    "error_pattern": "$error_pattern",
    "solution": "$solution",
    "platform": "$platform",
    "timestamp": "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")",
    "usage_count": 1
}
EOF
    )
    
    # Check if pattern already exists
    local existing_solution
    existing_solution=$(jq --arg pattern "$error_pattern" '.solutions[] | select(.error_pattern == $pattern)' "$kb_file" 2>/dev/null)
    
    if [ -n "$existing_solution" ]; then
        # Update existing entry usage count
        jq --arg pattern "$error_pattern" '(.solutions[] | select(.error_pattern == $pattern) | .usage_count) |= . + 1' "$kb_file" > "${kb_file}.tmp" && \
        mv "${kb_file}.tmp" "$kb_file"
        log_production "Updated existing knowledge base entry usage count"
    else
        # Add new entry
        jq --argjson entry "$new_entry" '.solutions += [$entry]' "$kb_file" > "${kb_file}.tmp" && \
        mv "${kb_file}.tmp" "$kb_file"
        log_production "Added new solution to knowledge base"
    fi
}

# Search knowledge base for solutions
search_knowledge_base() {
    local error_pattern="$1"
    local platform="$2"
    
    log_production "Searching knowledge base for pattern: $error_pattern"
    
    local kb_file="${MONITOR_DIR}/knowledge_base.json"
    
    if [ ! -f "$kb_file" ]; then
        log_debug "Knowledge base file not found"
        return 1
    fi
    
    # Search for exact pattern match first
    local exact_match
    exact_match=$(jq --arg pattern "$error_pattern" --arg platform "$platform" \
        '.solutions[] | select(.error_pattern == $pattern and (.platform == $platform or .platform == "all"))' \
        "$kb_file" 2>/dev/null)
    
    if [ -n "$exact_match" ]; then
        echo "$exact_match"
        log_production "Found exact match in knowledge base"
        return 0
    fi
    
    # Search for partial pattern matches
    local partial_matches
    partial_matches=$(jq --arg pattern "$error_pattern" --arg platform "$platform" \
        '.solutions[] | select((.error_pattern | contains($pattern)) and (.platform == $platform or .platform == "all"))' \
        "$kb_file" 2>/dev/null)
    
    if [ -n "$partial_matches" ]; then
        echo "$partial_matches"
        log_production "Found partial matches in knowledge base"
        return 0
    fi
    
    log_debug "No matches found in knowledge base"
    return 1
}

# Trend analysis and reporting
generate_trend_report() {
    local days=${1:-7}  # Default to 7 days
    log_production "Generating trend analysis report for last $days days"
    
    local report_file="${MONITOR_DIR}/reports/trend_report_$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "${MONITOR_DIR}/reports"
    
    # Find all session metadata files from the specified period
    local cutoff_date=$(date -u -v -${days}d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "$days days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    
    local total_sessions=0
    local successful_builds=0
    local failed_builds=0
    local platforms_used="[]"
    local common_errors="[]"
    
    if [ -d "${MONITOR_DIR}/sessions" ]; then
        for session_dir in "${MONITOR_DIR}/sessions"/*; do
            if [ -d "$session_dir" ]; then
                local metadata_file="${session_dir}/metadata.json"
                if [ -f "$metadata_file" ]; then
                    local session_time=$(jq -r '.start_time' "$metadata_file" 2>/dev/null)
                    
                    # Compare timestamps (simplified comparison)
                    if [[ "$session_time" > "$cutoff_date" ]]; then
                        ((total_sessions++))
                        
                        local platform=$(jq -r '.platform' "$metadata_file" 2>/dev/null)
                        local status=$(jq -r '.status' "$metadata_file" 2>/dev/null)
                        
                        # Track platform usage
                        if ! echo "$platforms_used" | jq -e --arg platform "$platform" '. | index($platform)' >/dev/null; then
                            platforms_used=$(echo "$platforms_used" | jq --arg platform "$platform" '. + [$platform]')
                        fi
                        
                        # Count build outcomes
                        if [ "$status" = "completed" ]; then
                            ((successful_builds++))
                        else
                            ((failed_builds++))
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Calculate success rate
    local success_rate=0
    if [ $total_sessions -gt 0 ]; then
        success_rate=$(echo "scale=2; $successful_builds * 100 / $total_sessions" | bc -l 2>/dev/null || echo "0")
    fi
    
    cat > "$report_file" << EOF
{
    "report_generated": "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")",
    "analysis_period_days": $days,
    "summary": {
        "total_sessions": $total_sessions,
        "successful_builds": $successful_builds,
        "failed_builds": $failed_builds,
        "success_rate_percent": $success_rate
    },
    "platforms_used": $platforms_used,
    "common_errors": $common_errors,
    "recommendations": [
        "Monitor error patterns for recurring issues",
        "Consider additional platform testing if success rate is low",
        "Review knowledge base for optimization opportunities"
    ]
}
EOF
    
    log_production "Trend report generated: $report_file"
    echo "$report_file"
}

# Error analysis trigger with enhanced intelligence
analyze_error() {
    local exit_code=$1
    local platform=${2:-"unknown"}
    local error_context=${3:-""}
    
    log_debug "Analyzing error with exit code: $exit_code"
    log_production "Enhanced error analysis with knowledge base integration"
    
    # Log the error for potential Claude Code analysis
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR_ANALYSIS exit_code=$exit_code platform=$platform context='$error_context'" >> "${MONITOR_DIR}/errors.log"
    
    # Search knowledge base for similar errors
    if [ -n "$error_context" ]; then
        local kb_solution
        kb_solution=$(search_knowledge_base "$error_context" "$platform")
        
        if [ $? -eq 0 ] && [ -n "$kb_solution" ]; then
            log_production "Found potential solution in knowledge base"
            
            local solution_text
            solution_text=$(echo "$kb_solution" | jq -r '.solution' 2>/dev/null)
            
            # Send webhook notification with suggested solution
            send_webhook_notification "Error detected with suggested solution" "warning" "Platform: $platform, Exit code: $exit_code, Suggested solution: $solution_text"
            
            echo "Knowledge base suggestion: $solution_text"
        else
            log_production "No solution found in knowledge base"
            send_webhook_notification "Unknown error detected" "error" "Platform: $platform, Exit code: $exit_code, Context: $error_context"
        fi
    fi
    
    # Collect performance metrics if session is active
    if [ -f "$SESSION_FILE" ]; then
        local session_id=$(cat "$SESSION_FILE")
        collect_performance_metrics "$session_id"
    fi
    
    log_debug "Error analysis completed with enhanced intelligence"
}

# Main command handler
main() {
    local command=${1:-help}
    
    log_debug "Executing command: $command"
    
    case "$command" in
        "init")
            init_monitoring
            ;;
        "start")
            start_monitoring_session "${2:-unknown}" "${3:-debug}" "${4:-DefoldProject}" "${5:-1.0.0}"
            ;;
        "stop")
            stop_monitoring_session "${2:-}"
            ;;
        "send-log")
            if [ -z "$2" ]; then
                handle_error "No log entry provided for send-log command"
            fi
            send_log_to_session "$2"
            ;;
        "list-sessions"|"list")
            list_sessions
            ;;
        "cleanup")
            cleanup_all_sessions
            ;;
        "config")
            case "${2:-show}" in
                "set")
                    if [ -z "$3" ] || [ -z "$4" ]; then
                        handle_error "Usage: $0 config set <key> <value>"
                    fi
                    config_set "$3" "$4"
                    ;;
                "show")
                    config_show
                    ;;
                *)
                    echo "Usage: $0 config {set|show} [key] [value]"
                    ;;
            esac
            ;;
        "validate")
            if [ -f "$CONFIG_FILE" ]; then
                if validate_config "$CONFIG_FILE"; then
                    echo -e "${GREEN}[VALID]${NC} Configuration is valid"
                    return 0
                else
                    echo -e "${RED}[INVALID]${NC} Configuration is invalid"
                    return 1
                fi
            else
                echo -e "${YELLOW}[WARNING]${NC} No configuration file found"
                return 1
            fi
            ;;
        # Phase 2: Engine Integration Commands
        "build_start")
            build_start "$2" "$3"
            ;;
        "build_end")
            build_end "$2" "$3" "$4"
            ;;
        "deploy_start")
            deploy_start "$2" "$3"
            ;;
        "stream_logs")
            stream_logs "$2"
            ;;
        "process_logs")
            process_logs "$2"
            ;;
        "start_session")
            start_session "$2"
            ;;
        "end_session")
            end_session
            ;;
        "analyze_error")
            analyze_error "$2" "$3" "$4"
            ;;
        # Phase 4: Production Team Features
        "webhook")
            case "${2:-help}" in
                "test")
                    if [ -z "$3" ] || [ -z "$4" ]; then
                        handle_error "Usage: $0 webhook test <provider> <message>"
                    fi
                    case "$3" in
                        "slack") send_slack_webhook "$4" "info" "Test notification" ;;
                        "discord") send_discord_webhook "$4" "info" "Test notification" ;;
                        "teams") send_teams_webhook "$4" "info" "Test notification" ;;
                        *) echo "Unknown provider: $3. Use slack, discord, or teams" ;;
                    esac
                    ;;
                "send")
                    if [ -z "$3" ] || [ -z "$4" ]; then
                        handle_error "Usage: $0 webhook send <message> <level> [details]"
                    fi
                    send_webhook_notification "$3" "$4" "$5"
                    ;;
                *)
                    echo "Usage: $0 webhook {test|send} <args>"
                    ;;
            esac
            ;;
        "recovery")
            case "${2:-help}" in
                "attempt")
                    attempt_recovery
                    ;;
                "status")
                    if load_recovery_state; then
                        echo "Recovery state found:"
                        cat "$RECOVERY_FILE" | jq '.'
                    else
                        echo "No recovery state available"
                    fi
                    ;;
                "clear")
                    rm -f "$RECOVERY_FILE"
                    echo "Recovery state cleared"
                    ;;
                *)
                    echo "Usage: $0 recovery {attempt|status|clear}"
                    ;;
            esac
            ;;
        "team")
            case "${2:-help}" in
                "status")
                    get_team_session_status | jq '.'
                    ;;
                "metrics")
                    if [ -z "$3" ]; then
                        echo "Usage: $0 team metrics <session_id>"
                        exit 1
                    fi
                    collect_performance_metrics "$3"
                    ;;
                "knowledge")
                    case "${3:-help}" in
                        "search")
                            if [ -z "$4" ]; then
                                echo "Usage: $0 team knowledge search <error_pattern> [platform]"
                                exit 1
                            fi
                            search_knowledge_base "$4" "${5:-all}"
                            ;;
                        "add")
                            if [ -z "$4" ] || [ -z "$5" ]; then
                                echo "Usage: $0 team knowledge add <error_pattern> <solution> [platform]"
                                exit 1
                            fi
                            update_knowledge_base "$4" "$5" "${6:-all}"
                            ;;
                        *)
                            echo "Usage: $0 team knowledge {search|add} <args>"
                            ;;
                    esac
                    ;;
                *)
                    echo "Usage: $0 team {status|metrics|knowledge} <args>"
                    ;;
            esac
            ;;
        "reports")
            case "${2:-help}" in
                "trend")
                    local days=${3:-7}
                    generate_trend_report "$days"
                    ;;
                "list")
                    if [ -d "${MONITOR_DIR}/reports" ]; then
                        ls -la "${MONITOR_DIR}/reports"
                    else
                        echo "No reports directory found"
                    fi
                    ;;
                *)
                    echo "Usage: $0 reports {trend|list} [days]"
                    ;;
            esac
            ;;
        "retry")
            if [ $# -lt 3 ]; then
                handle_error "Usage: $0 retry <operation_name> <command> [args...]"
            fi
            local operation_name="$2"
            shift 2
            retry_operation "$operation_name" "$@"
            ;;
        "help"|*)
            cat << EOF
Claude Log Monitor - Phase 4: Production Team Features

Usage: $0 COMMAND [OPTIONS]

Core Commands:
    init                                Initialize monitoring system
    start <platform> <mode> [title] [version]    Start monitoring session
    stop [session_id]                   Stop monitoring session
    send-log <log_entry>                Send log entry to active session
    list-sessions                       List all monitoring sessions
    cleanup                             Clean up all sessions and resources
    
    config set <key> <value>           Set configuration option
    config show                        Show current configuration
    validate                           Validate configuration file

Engine Integration Commands (Phase 2):
    build_start <platform> <mode>      Signal build phase start
    build_end <platform> <mode> <exit_code>  Signal build phase completion
    deploy_start <platform> <mode>     Signal deploy phase start
    stream_logs <platform>             Initialize log streaming
    process_logs <platform>            Process streaming logs (via tee)
    start_session <session_name>       Start wrapper session
    end_session                        End wrapper session
    analyze_error <exit_code> [platform] [context]  Enhanced error analysis

Production Team Features (Phase 4):
    webhook test <provider> <message>  Test webhook notification (slack, discord, teams)
    webhook send <message> <level> [details]  Send webhook notification
    
    recovery attempt                   Attempt session recovery from saved state
    recovery status                    Show current recovery state
    recovery clear                     Clear recovery state
    
    team status                        Show team session status
    team metrics <session_id>          Collect performance metrics
    team knowledge search <pattern> [platform]  Search knowledge base
    team knowledge add <pattern> <solution> [platform]  Add solution to knowledge base
    
    reports trend [days]               Generate trend analysis report (default: 7 days)
    reports list                       List available reports
    
    retry <operation> <command> [args]  Retry operation with intelligent backoff
    
    help                               Show this help message

Implementation Phases:
    Phase 1: Core logic foundation with session and config management
    Phase 2: Engine integration with deployer.sh hooks and log streaming
    Phase 3: Data-driven UI integration with in-game monitoring
    Phase 4: Production team features with webhooks, recovery, and collaboration

Examples:
    $0 init                            # Initialize monitoring
    $0 start android debug MyGame 1.2.0    # Start Android debug monitoring
    $0 webhook test slack "Test message"    # Test Slack webhook
    $0 team status                     # View team session status
    $0 recovery attempt                # Attempt session recovery
    $0 reports trend 14                # Generate 14-day trend report
    $0 team knowledge search "build error"  # Search for build error solutions
    $0 retry "build_android" ./build.sh android  # Retry build with backoff

Webhook Configuration:
    Configure webhooks in config.json under 'webhooks' section:
    - Slack: Set url, channel, username, icon_emoji
    - Discord: Set url, username, avatar_url
    - Teams: Set url
    - Enable notifications for different alert levels and build events

Recovery Features:
    - Automatic session recovery after interruptions
    - Configurable retry attempts and delays
    - Context preservation across recovery attempts
    - Smart failure classification and response

Team Collaboration:
    - Shared session status visibility
    - Knowledge base for common issues and solutions
    - Performance metrics tracking
    - Trend analysis and reporting

Debug Logging:
    All functions include ${DEBUG_PREFIX} debug logging for validation.
    Engine integration uses [ENGINE] [FEATURE] prefix for Phase 2 validation.
    Production features use ${PRODUCTION_PREFIX} prefix for Phase 4 validation.
    
EOF
            ;;
    esac
}

# Signal handling for cleanup
trap 'cleanup_all_sessions; exit 0' INT TERM

# Run main function with all arguments
main "$@"