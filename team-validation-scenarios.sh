#!/opt/homebrew/bin/bash
# Team Validation Scenarios - Real-world use cases for Claude Code monitoring
# Phase 5: Backstage Demo component for team onboarding and validation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="${SCRIPT_DIR}/claude-log-monitor.sh"

# Team validation logging
TEAM_PREFIX="[TEAM-VALIDATION]"

log_team() {
    echo -e "${CYAN}${TEAM_PREFIX}${NC} $*"
}

# Scenario execution framework
run_scenario() {
    local scenario_name="$1"
    local scenario_description="$2"
    shift 2
    local steps=("$@")
    
    echo -e "\n${PURPLE}🎯 TEAM VALIDATION SCENARIO${NC}"
    echo -e "${PURPLE}Scenario: $scenario_name${NC}"
    echo -e "${BLUE}Description: $scenario_description${NC}"
    echo ""
    
    log_team "Starting scenario: $scenario_name"
    
    local step_num=1
    for step in "${steps[@]}"; do
        echo -e "${YELLOW}Step $step_num:${NC} $step"
        echo -e "${CYAN}Press Enter to execute this step or 's' to skip...${NC}"
        read -r input
        
        if [[ "$input" != "s" ]]; then
            echo -e "${BLUE}Executing:${NC} $step"
            if eval "$step"; then
                echo -e "${GREEN}✅ Step $step_num completed successfully${NC}"
            else
                echo -e "${RED}❌ Step $step_num failed${NC}"
                echo -e "${YELLOW}Continuing with next step...${NC}"
            fi
        else
            echo -e "${YELLOW}⏭️  Step $step_num skipped${NC}"
        fi
        
        ((step_num++))
        echo ""
    done
    
    log_team "Scenario completed: $scenario_name"
    echo -e "${CYAN}---${NC}"
}

# Scenario 1: New Developer Onboarding
scenario_new_developer() {
    local steps=(
        "echo 'Welcome! Let\\'s set up the Claude Code monitoring system'"
        "$MONITOR_SCRIPT init"
        "$MONITOR_SCRIPT validate"
        "$MONITOR_SCRIPT config show"
        "$MONITOR_SCRIPT help"
        "echo 'Setup complete! You\\'re ready to monitor builds.'"
    )
    
    run_scenario "New Developer Onboarding" \
        "A new team member needs to set up and understand the monitoring system" \
        "${steps[@]}"
}

# Scenario 2: Daily Development Workflow
scenario_daily_workflow() {
    local steps=(
        "echo 'Starting daily development workflow'"
        "$MONITOR_SCRIPT start android debug MyGame 1.2.0"
        "$MONITOR_SCRIPT status"
        "echo 'Simulating build process...'"
        "$MONITOR_SCRIPT build_start android debug"
        "sleep 2"
        "$MONITOR_SCRIPT build_end android debug 0"
        "$MONITOR_SCRIPT stop"
        "echo 'Daily workflow complete!'"
    )
    
    run_scenario "Daily Development Workflow" \
        "Typical developer workflow: start monitoring, run build, check results" \
        "${steps[@]}"
}

# Scenario 3: Build Failure Investigation
scenario_build_failure() {
    local steps=(
        "echo 'Investigating build failure scenario'"
        "$MONITOR_SCRIPT start ios release MyGame 1.2.0"
        "$MONITOR_SCRIPT build_start ios release"
        "echo 'Simulating build failure...'"
        "$MONITOR_SCRIPT build_end ios release 1"
        "$MONITOR_SCRIPT analyze_error 1 ios 'Compilation error in main.cpp line 45'"
        "$MONITOR_SCRIPT team knowledge search 'compilation error' ios"
        "$MONITOR_SCRIPT team knowledge add 'compilation error main.cpp' 'Check include paths and dependencies' ios"
        "$MONITOR_SCRIPT stop"
        "echo 'Build failure investigation complete'"
    )
    
    run_scenario "Build Failure Investigation" \
        "How to investigate and document solutions for build failures" \
        "${steps[@]}"
}

# Scenario 4: Multi-Platform Release
scenario_multi_platform() {
    local steps=(
        "echo 'Starting multi-platform release monitoring'"
        "$MONITOR_SCRIPT start android release MyGame 2.0.0"
        "$MONITOR_SCRIPT build_start android release"
        "$MONITOR_SCRIPT build_end android release 0"
        "$MONITOR_SCRIPT stop"
        "$MONITOR_SCRIPT start ios release MyGame 2.0.0"
        "$MONITOR_SCRIPT build_start ios release"
        "$MONITOR_SCRIPT build_end ios release 0"
        "$MONITOR_SCRIPT stop"
        "$MONITOR_SCRIPT start windows release MyGame 2.0.0"
        "$MONITOR_SCRIPT build_start windows release"
        "$MONITOR_SCRIPT build_end windows release 0"
        "$MONITOR_SCRIPT cleanup"
        "echo 'Multi-platform release monitoring complete'"
    )
    
    run_scenario "Multi-Platform Release" \
        "Managing builds across multiple platforms for a major release" \
        "${steps[@]}"
}

# Scenario 5: Team Collaboration
scenario_team_collaboration() {
    local steps=(
        "echo 'Demonstrating team collaboration features'"
        "$MONITOR_SCRIPT team status"
        "$MONITOR_SCRIPT team knowledge search 'build error'"
        "$MONITOR_SCRIPT team knowledge add 'memory leak' 'Use Valgrind or AddressSanitizer' 'general'"
        "$MONITOR_SCRIPT team knowledge search 'memory'"
        "echo 'Testing webhook notifications (will show disabled message)'"
        "$MONITOR_SCRIPT webhook send 'Team build completed' 'success' 'All platforms built successfully'"
        "$MONITOR_SCRIPT recovery status"
        "echo 'Team collaboration features demonstrated'"
    )
    
    run_scenario "Team Collaboration" \
        "Using shared knowledge base, webhooks, and team features" \
        "${steps[@]}"
}

# Scenario 6: CI/CD Integration
scenario_cicd_integration() {
    local steps=(
        "echo 'Simulating CI/CD pipeline integration'"
        "echo 'Pipeline step 1: Initialize monitoring'"
        "$MONITOR_SCRIPT init"
        "echo 'Pipeline step 2: Start build monitoring'"
        "$MONITOR_SCRIPT start android release MyGame 1.5.0"
        "echo 'Pipeline step 3: Execute build with monitoring'"
        "$MONITOR_SCRIPT build_start android release"
        "sleep 3"
        "$MONITOR_SCRIPT build_end android release 0"
        "echo 'Pipeline step 4: Collect metrics'"
        "$MONITOR_SCRIPT team metrics \$(date +%s)"
        "echo 'Pipeline step 5: Cleanup'"
        "$MONITOR_SCRIPT cleanup"
        "echo 'CI/CD integration simulation complete'"
    )
    
    run_scenario "CI/CD Integration" \
        "How to integrate monitoring into automated build pipelines" \
        "${steps[@]}"
}

# Scenario 7: Performance Analysis
scenario_performance_analysis() {
    local steps=(
        "echo 'Starting performance analysis scenario'"
        "$MONITOR_SCRIPT start android debug MyGame 1.0.0"
        "echo 'Collecting baseline metrics...'"
        "$MONITOR_SCRIPT team metrics baseline-\$(date +%s)"
        "$MONITOR_SCRIPT build_start android debug"
        "sleep 2"
        "$MONITOR_SCRIPT build_end android debug 0"
        "echo 'Generating performance report...'"
        "$MONITOR_SCRIPT reports trend 7"
        "$MONITOR_SCRIPT reports list"
        "$MONITOR_SCRIPT stop"
        "echo 'Performance analysis complete'"
    )
    
    run_scenario "Performance Analysis" \
        "Tracking build performance and generating trend reports" \
        "${steps[@]}"
}

# Scenario 8: Error Recovery
scenario_error_recovery() {
    local steps=(
        "echo 'Demonstrating error recovery capabilities'"
        "$MONITOR_SCRIPT start android debug MyGame 1.0.0"
        "echo 'Simulating build interruption...'"
        "$MONITOR_SCRIPT build_start android debug"
        "echo 'Simulating recovery from interruption...'"
        "$MONITOR_SCRIPT recovery status"
        "$MONITOR_SCRIPT recovery attempt"
        "echo 'Testing retry mechanism...'"
        "$MONITOR_SCRIPT retry build \"\$MONITOR_SCRIPT build_end android debug 0\""
        "$MONITOR_SCRIPT stop"
        "$MONITOR_SCRIPT recovery clear"
        "echo 'Error recovery demonstration complete'"
    )
    
    run_scenario "Error Recovery" \
        "How the system handles interruptions and enables recovery" \
        "${steps[@]}"
}

# Main menu
show_menu() {
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${PURPLE}      TEAM VALIDATION SCENARIOS MENU${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo ""
    echo -e "${CYAN}Available scenarios:${NC}"
    echo -e "${YELLOW}1.${NC} New Developer Onboarding"
    echo -e "${YELLOW}2.${NC} Daily Development Workflow"
    echo -e "${YELLOW}3.${NC} Build Failure Investigation"
    echo -e "${YELLOW}4.${NC} Multi-Platform Release"
    echo -e "${YELLOW}5.${NC} Team Collaboration"
    echo -e "${YELLOW}6.${NC} CI/CD Integration"
    echo -e "${YELLOW}7.${NC} Performance Analysis"
    echo -e "${YELLOW}8.${NC} Error Recovery"
    echo -e "${YELLOW}9.${NC} Run All Scenarios"
    echo -e "${YELLOW}0.${NC} Exit"
    echo ""
}

# Run all scenarios
run_all_scenarios() {
    echo -e "${PURPLE}Running all team validation scenarios...${NC}"
    log_team "Starting comprehensive team validation"
    
    scenario_new_developer
    scenario_daily_workflow
    scenario_build_failure
    scenario_multi_platform
    scenario_team_collaboration
    scenario_cicd_integration
    scenario_performance_analysis
    scenario_error_recovery
    
    echo -e "\n${GREEN}🎉 All team validation scenarios completed!${NC}"
    log_team "Comprehensive team validation completed"
}

# Main execution
main() {
    log_team "Team validation scenarios started"
    
    while true; do
        show_menu
        echo -e "${CYAN}Enter your choice (0-9):${NC}"
        read -r choice
        
        case $choice in
            1) scenario_new_developer ;;
            2) scenario_daily_workflow ;;
            3) scenario_build_failure ;;
            4) scenario_multi_platform ;;
            5) scenario_team_collaboration ;;
            6) scenario_cicd_integration ;;
            7) scenario_performance_analysis ;;
            8) scenario_error_recovery ;;
            9) run_all_scenarios ;;
            0) 
                echo -e "${CYAN}Thank you for using team validation scenarios!${NC}"
                log_team "Team validation scenarios session ended"
                exit 0 
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 0-9.${NC}"
                ;;
        esac
        
        echo -e "\n${CYAN}Press Enter to return to menu...${NC}"
        read -r
    done
}

# Help function
show_help() {
    echo "Team Validation Scenarios - Real-world use cases for team validation"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  menu        Show interactive menu (default)"
    echo "  all         Run all scenarios non-interactively"
    echo "  help        Show this help message"
    echo ""
    echo "Available scenarios:"
    echo "  1. New Developer Onboarding"
    echo "  2. Daily Development Workflow"
    echo "  3. Build Failure Investigation"
    echo "  4. Multi-Platform Release"
    echo "  5. Team Collaboration"
    echo "  6. CI/CD Integration"
    echo "  7. Performance Analysis"
    echo "  8. Error Recovery"
}

# Entry point
case "${1:-menu}" in
    "menu")
        main
        ;;
    "all")
        run_all_scenarios
        ;;
    "help")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac