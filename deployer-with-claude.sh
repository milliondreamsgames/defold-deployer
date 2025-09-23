#!/opt/homebrew/bin/bash
# deployer-with-claude.sh - Enhanced wrapper for Defold Deployer with Claude Code integration
# Phase 2: Engine Integration Wrapper Script

set -euo pipefail

# Enhanced wrapper configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYER_SCRIPT="${SCRIPT_DIR}/deployer.sh"
CLAUDE_MONITOR_SCRIPT="${SCRIPT_DIR}/claude-log-monitor.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Engine integration logging prefix for Phase 2 validation
ENGINE_PREFIX="[ENGINE] [FEATURE]"

log_engine() {
    echo -e "${CYAN}${ENGINE_PREFIX}${NC} $*"
}

# Display banner
show_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${PURPLE}Defold Deployer with Claude Code Integration${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                        ${YELLOW}Phase 2: Engine Integration${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Environment detection and setup
setup_environment() {
    log_engine "Setting up Claude Code monitoring environment"
    
    # Export Claude monitoring as enabled
    export CLAUDE_MONITORING_ENABLED=true
    log_engine "Claude monitoring enabled: ${CLAUDE_MONITORING_ENABLED}"
    
    # Validate required components
    if [ ! -f "$DEPLOYER_SCRIPT" ]; then
        echo -e "${RED}ERROR: Deployer script not found at $DEPLOYER_SCRIPT${NC}"
        exit 1
    fi
    
    if [ ! -f "$CLAUDE_MONITOR_SCRIPT" ]; then
        echo -e "${YELLOW}WARNING: Claude monitor script not found at $CLAUDE_MONITOR_SCRIPT${NC}"
        echo -e "${YELLOW}Monitoring features will be limited${NC}"
        export CLAUDE_MONITORING_ENABLED=false
    fi
    
    # Platform detection
    local -i platform_count=0
    local platforms_detected=()

    for arg in "$@"; do
        case "$arg" in
            *a*) platforms_detected+=("Android"); platform_count=$((platform_count+1)) ;;
        esac
        case "$arg" in
            *i*) platforms_detected+=("iOS"); platform_count=$((platform_count+1)) ;;
        esac
        case "$arg" in
            *h*) platforms_detected+=("HTML5"); platform_count=$((platform_count+1)) ;;
        esac
        case "$arg" in
            *w*) platforms_detected+=("Windows"); platform_count=$((platform_count+1)) ;;
        esac
        case "$arg" in
            *l*) platforms_detected+=("Linux"); platform_count=$((platform_count+1)) ;;
        esac
        case "$arg" in
            *m*) platforms_detected+=("macOS"); platform_count=$((platform_count+1)) ;;
        esac
    done
    
    if [ $platform_count -eq 0 ]; then
        log_engine "No platforms detected in arguments - running deployer with current args"
    else
        log_engine "Target platforms detected: ${platforms_detected[@]}"
        log_engine "Platform count: $platform_count"
    fi
    
    # Mode detection
    local mode="debug"
    case "$*" in
        *r*) mode="release" ;;
    esac
    case "$*" in
        *--headless*) mode="headless" ;;
    esac
    log_engine "Build mode detected: $mode"

    # Check for build and deploy flags
    local is_build=false
    local is_deploy=false
    case "$*" in
        *b*) is_build=true; log_engine "Build phase will be executed" ;;
    esac
    case "$*" in
        *d*) is_deploy=true; log_engine "Deploy phase will be executed" ;;
    esac

    return 0
}

# Initialize Claude monitoring if available
initialize_monitoring() {
    if [ "$CLAUDE_MONITORING_ENABLED" = "true" ] && [ -f "$CLAUDE_MONITOR_SCRIPT" ]; then
        log_engine "Initializing Claude Code monitoring system"
        
        # Initialize the monitoring system
        if "$CLAUDE_MONITOR_SCRIPT" init 2>/dev/null; then
            log_engine "Claude monitoring initialized successfully"
        else
            log_engine "Claude monitoring initialization had warnings - continuing"
        fi
        
        # Start session tracking
        if "$CLAUDE_MONITOR_SCRIPT" start_session "deployer-with-claude" 2>/dev/null; then
            log_engine "Claude monitoring session started"
        else
            log_engine "Claude monitoring session start had warnings - continuing"
        fi
    else
        log_engine "Claude monitoring disabled or unavailable - running in compatibility mode"
    fi
}

# Cleanup monitoring on exit
cleanup_monitoring() {
    if [ "$CLAUDE_MONITORING_ENABLED" = "true" ] && [ -f "$CLAUDE_MONITOR_SCRIPT" ]; then
        log_engine "Cleaning up Claude monitoring session"
        "$CLAUDE_MONITOR_SCRIPT" end_session 2>/dev/null || true
    fi
}

# Enhanced error handling
handle_error() {
    local exit_code=$?
    log_engine "Build process encountered an error (exit code: $exit_code)"
    
    # Trigger automated troubleshooting if monitoring is enabled
    if [ "$CLAUDE_MONITORING_ENABLED" = "true" ] && [ -f "$CLAUDE_MONITOR_SCRIPT" ]; then
        log_engine "Triggering automated troubleshooting analysis"
        "$CLAUDE_MONITOR_SCRIPT" analyze_error "$exit_code" 2>/dev/null || true
    fi
    
    cleanup_monitoring
    exit $exit_code
}

# Signal handlers
trap cleanup_monitoring EXIT
trap handle_error ERR

# Main execution
main() {
    show_banner
    setup_environment "$@"
    initialize_monitoring
    
    log_engine "Starting enhanced deployer execution"
    log_engine "Command: $DEPLOYER_SCRIPT $*"
    
    # Execute the original deployer with all arguments
    # The monitoring hooks are already integrated into deployer.sh
    "$DEPLOYER_SCRIPT" "$@"
    
    local deployer_exit_code=$?
    
    if [ $deployer_exit_code -eq 0 ]; then
        log_engine "Deployer completed successfully"
    else
        log_engine "Deployer completed with errors (exit code: $deployer_exit_code)"
    fi
    
    cleanup_monitoring
    return $deployer_exit_code
}

# Show usage if no arguments provided
if [ $# -eq 0 ]; then
    show_banner
    echo "Usage: $0 [deployer arguments]"
    echo ""
    echo "This enhanced wrapper enables Claude Code monitoring for the Defold deployer."
    echo ""
    echo "Examples:"
    echo "  $0 abd        # Build and deploy Android bundle with Claude monitoring"  
    echo "  $0 ibdr       # Build and deploy iOS release bundle with Claude monitoring"
    echo "  $0 aibr       # Build Android and iOS release bundles with Claude monitoring"
    echo ""
    echo "Monitoring Environment Variables:"
    echo "  CLAUDE_MONITORING_ENABLED - Set to 'true' to enable monitoring (auto-enabled by this wrapper)"
    echo ""
    echo "For standard deployer usage without Claude integration, use deployer.sh directly."
    exit 0
fi

# Execute main function with all arguments
main "$@"