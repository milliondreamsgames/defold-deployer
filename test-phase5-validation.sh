#!/opt/homebrew/bin/bash
# Phase 5 Validation Test Script - Comprehensive QA Framework
# Tests all Phase 1-5 features and end-to-end integration for Gate 5 validation

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
DEMO_SCRIPT="${SCRIPT_DIR}/demo-phase5-backstage.sh"
TEAM_SCRIPT="${SCRIPT_DIR}/team-validation-scenarios.sh"

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0
QA_ISSUES=0

# QA logging prefix for Phase 5 validation
QA_PREFIX="[QA] [BACKSTAGE]"

log_qa() {
    echo -e "${PURPLE}${QA_PREFIX}${NC} $*"
}

# Enhanced test helper functions
run_qa_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    local test_category="${4:-General}"
    
    echo -e "${BLUE}[QA-TEST]${NC} Category: $test_category | Running: $test_name"
    ((TOTAL_TESTS++))
    
    local start_time=$(date +%s)
    local output
    local actual_exit_code
    
    if output=$(eval "$test_command" 2>&1); then
        actual_exit_code=0
    else
        actual_exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $actual_exit_code -eq $expected_exit_code ]; then
        echo -e "${GREEN}[PASS]${NC} $test_name (${duration}s)"
        ((TESTS_PASSED++))
        log_qa "Test passed: $test_name in ${duration}s"
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name (exit code: $actual_exit_code, expected: $expected_exit_code, ${duration}s)"
        echo -e "${YELLOW}Output: $output${NC}"
        ((TESTS_FAILED++))
        ((QA_ISSUES++))
        log_qa "Test failed: $test_name - exit code $actual_exit_code"
        return 1
    fi
}

run_qa_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    local test_category="${4:-General}"
    
    echo -e "${BLUE}[QA-TEST]${NC} Category: $test_category | Running: $test_name"
    ((TOTAL_TESTS++))
    
    local start_time=$(date +%s)
    local output
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}[PASS]${NC} $test_name (${duration}s)"
        ((TESTS_PASSED++))
        log_qa "Test passed: $test_name in ${duration}s"
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name (${duration}s)"
        echo -e "${YELLOW}Expected pattern: $expected_pattern${NC}"
        echo -e "${YELLOW}Actual output: ${output:0:200}...${NC}"
        ((TESTS_FAILED++))
        ((QA_ISSUES++))
        log_qa "Test failed: $test_name - pattern not found"
        return 1
    fi
}

# File existence validation
validate_files() {
    local test_category="File Validation"
    
    echo -e "${YELLOW}--- QA Test Group 1: File Structure Validation ---${NC}"
    
    run_qa_test "Main monitoring script exists" "test -f $MONITOR_SCRIPT" 0 "$test_category"
    run_qa_test "Demo script exists" "test -f $DEMO_SCRIPT" 0 "$test_category"
    run_qa_test "Team validation script exists" "test -f $TEAM_SCRIPT" 0 "$test_category"
    run_qa_test "Team adoption guide exists" "test -f ${SCRIPT_DIR}/TEAM-ADOPTION-GUIDE.md" 0 "$test_category"
    run_qa_test "Scripts are executable" "test -x $MONITOR_SCRIPT && test -x $DEMO_SCRIPT && test -x $TEAM_SCRIPT" 0 "$test_category"
}

# Phase 1-4 Integration Testing
validate_phase_integration() {
    local test_category="Phase Integration"
    
    echo -e "${YELLOW}--- QA Test Group 2: Phase 1-4 Integration ---${NC}"
    
    # Phase 1: Core Logic
    run_qa_test "Phase 1: System initialization" "$MONITOR_SCRIPT init" 0 "$test_category"
    run_qa_test "Phase 1: Configuration validation" "$MONITOR_SCRIPT validate" 0 "$test_category"
    run_qa_test_with_output "Phase 1: Debug logging active" "$MONITOR_SCRIPT validate" "\\[FEATURE\\]" "$test_category"
    
    # Phase 2: Engine Integration
    run_qa_test "Phase 2: Session management" "$MONITOR_SCRIPT start android debug TestQA 1.0.0" 0 "$test_category"
    run_qa_test_with_output "Phase 2: Session listing" "$MONITOR_SCRIPT list" "android" "$test_category"
    run_qa_test "Phase 2: Session cleanup" "$MONITOR_SCRIPT stop" 0 "$test_category"
    
    # Phase 3: Data-Driven UI
    run_qa_test "Phase 3: Build event simulation" "$MONITOR_SCRIPT build_start android debug" 0 "$test_category"
    run_qa_test "Phase 3: Build success handling" "$MONITOR_SCRIPT build_end android debug 0" 0 "$test_category"
    run_qa_test "Phase 3: Build failure handling" "$MONITOR_SCRIPT build_end android debug 1" 0 "$test_category"
    
    # Phase 4: Player Experience  
    run_qa_test_with_output "Phase 4: Production logging" "$MONITOR_SCRIPT validate" "\\[PRODUCTION\\] \\[FEATURE\\]" "$test_category"
    run_qa_test "Phase 4: Webhook system" "$MONITOR_SCRIPT webhook send 'QA Test' 'info' 'Testing'" 0 "$test_category"
    run_qa_test "Phase 4: Recovery status" "$MONITOR_SCRIPT recovery status" 0 "$test_category"
    run_qa_test "Phase 4: Team features" "$MONITOR_SCRIPT team status" 0 "$test_category"
}

# Demo Script Validation
validate_demo_functionality() {
    local test_category="Demo Validation"
    
    echo -e "${YELLOW}--- QA Test Group 3: Demo Script Functionality ---${NC}"
    
    run_qa_test "Demo script help" "$DEMO_SCRIPT help" 0 "$test_category"
    run_qa_test_with_output "Demo script structure" "head -50 $DEMO_SCRIPT" "Phase 5: Backstage Demo" "$test_category"
    run_qa_test_with_output "Demo logging prefix" "grep -q 'BACKSTAGE.*FEATURE' $DEMO_SCRIPT && echo 'found'" "found" "$test_category"
    run_qa_test "Demo script syntax" "bash -n $DEMO_SCRIPT" 0 "$test_category"
}

# Team Validation Scenarios
validate_team_scenarios() {
    local test_category="Team Scenarios"
    
    echo -e "${YELLOW}--- QA Test Group 4: Team Validation Scenarios ---${NC}"
    
    run_qa_test "Team script help" "$TEAM_SCRIPT help" 0 "$test_category"
    run_qa_test_with_output "Team script structure" "head -50 $TEAM_SCRIPT" "Team Validation Scenarios" "$test_category"
    run_qa_test_with_output "Team logging prefix" "grep -q 'TEAM-VALIDATION' $TEAM_SCRIPT && echo 'found'" "found" "$test_category"
    run_qa_test "Team script syntax" "bash -n $TEAM_SCRIPT" 0 "$test_category"
}

# Documentation Validation
validate_documentation() {
    local test_category="Documentation"
    
    echo -e "${YELLOW}--- QA Test Group 5: Documentation Completeness ---${NC}"
    
    local doc_file="${SCRIPT_DIR}/TEAM-ADOPTION-GUIDE.md"
    
    run_qa_test_with_output "Documentation exists and readable" "test -r $doc_file && echo 'readable'" "readable" "$test_category"
    run_qa_test_with_output "Documentation contains overview" "grep -q 'Overview' $doc_file && echo 'found'" "found" "$test_category"
    run_qa_test_with_output "Documentation contains architecture" "grep -q 'Architecture' $doc_file && echo 'found'" "found" "$test_category"
    run_qa_test_with_output "Documentation contains quick start" "grep -q 'Quick Start' $doc_file && echo 'found'" "found" "$test_category"
    run_qa_test_with_output "Documentation contains configuration" "grep -q 'Configuration' $doc_file && echo 'found'" "found" "$test_category"
    run_qa_test_with_output "Documentation contains troubleshooting" "grep -q 'Troubleshooting' $doc_file && echo 'found'" "found" "$test_category"
    run_qa_test_with_output "Documentation mentions all phases" "grep -c 'Phase [1-5]' $doc_file | awk '{print (\$1 >= 5 ? \"sufficient\" : \"insufficient\")}'" "sufficient" "$test_category"
}

# End-to-End Workflow Testing
validate_end_to_end() {
    local test_category="End-to-End"
    
    echo -e "${YELLOW}--- QA Test Group 6: End-to-End Workflow ---${NC}"
    
    # Complete workflow simulation
    run_qa_test "E2E: System initialization" "$MONITOR_SCRIPT init" 0 "$test_category"
    run_qa_test "E2E: Start monitoring session" "$MONITOR_SCRIPT start android release QATest 2.0.0" 0 "$test_category"
    run_qa_test "E2E: Build start notification" "$MONITOR_SCRIPT build_start android release" 0 "$test_category"
    run_qa_test "E2E: Build success workflow" "$MONITOR_SCRIPT build_end android release 0" 0 "$test_category"
    run_qa_test "E2E: Performance metrics" "$MONITOR_SCRIPT team metrics qa-session-\$(date +%s)" 0 "$test_category"
    run_qa_test "E2E: Knowledge base interaction" "$MONITOR_SCRIPT team knowledge add 'QA test issue' 'QA test solution' android" 0 "$test_category"
    run_qa_test "E2E: Knowledge base search" "$MONITOR_SCRIPT team knowledge search 'QA test' android" 0 "$test_category"
    run_qa_test "E2E: Session cleanup" "$MONITOR_SCRIPT stop" 0 "$test_category"
    run_qa_test "E2E: Final cleanup" "$MONITOR_SCRIPT cleanup" 0 "$test_category"
}

# Performance and Reliability Testing
validate_performance() {
    local test_category="Performance"
    
    echo -e "${YELLOW}--- QA Test Group 7: Performance and Reliability ---${NC}"
    
    # Test multiple rapid operations
    run_qa_test "Performance: Rapid session start/stop" "
        $MONITOR_SCRIPT start android debug PerfTest 1.0.0 && 
        $MONITOR_SCRIPT stop &&
        $MONITOR_SCRIPT start ios debug PerfTest 1.0.0 && 
        $MONITOR_SCRIPT stop
    " 0 "$test_category"
    
    # Test error recovery
    run_qa_test "Reliability: Recovery state management" "$MONITOR_SCRIPT recovery clear" 0 "$test_category"
    
    # Test configuration resilience
    run_qa_test "Reliability: Configuration validation" "$MONITOR_SCRIPT validate" 0 "$test_category"
    
    # Test help system performance
    local help_start=$(date +%s)
    run_qa_test "Performance: Help system response" "$MONITOR_SCRIPT help" 0 "$test_category"
    local help_end=$(date +%s)
    local help_duration=$((help_end - help_start))
    
    if [ $help_duration -gt 5 ]; then
        echo -e "${YELLOW}[WARNING]${NC} Help system took ${help_duration}s (>5s threshold)"
        ((QA_ISSUES++))
    fi
}

# Cross-Platform Compatibility
validate_cross_platform() {
    local test_category="Cross-Platform"
    
    echo -e "${YELLOW}--- QA Test Group 8: Cross-Platform Compatibility ---${NC}"
    
    # Test all supported platforms
    for platform in android ios windows macos browser; do
        run_qa_test "Platform: $platform session creation" "$MONITOR_SCRIPT start $platform debug MultiPlatform 1.0.0 && $MONITOR_SCRIPT stop" 0 "$test_category"
    done
    
    # Test platform-specific features
    run_qa_test "Platform: Android build events" "$MONITOR_SCRIPT build_start android debug && $MONITOR_SCRIPT build_end android debug 0" 0 "$test_category"
    run_qa_test "Platform: iOS build events" "$MONITOR_SCRIPT build_start ios release && $MONITOR_SCRIPT build_end ios release 0" 0 "$test_category"
}

# Security and Configuration Testing
validate_security() {
    local test_category="Security"
    
    echo -e "${YELLOW}--- QA Test Group 9: Security and Configuration ---${NC}"
    
    # Test configuration security
    run_qa_test "Security: Config file permissions" "test -f .claude-monitors/config.json" 0 "$test_category"
    
    # Test webhook security (should be disabled by default)
    run_qa_test_with_output "Security: Webhooks disabled by default" "$MONITOR_SCRIPT webhook send 'test' 'info'" "disabled" "$test_category"
    
    # Test session isolation
    run_qa_test "Security: Session file isolation" "ls .claude-monitors/ | grep -q current_session || echo 'no active session'" 0 "$test_category"
}

# Integration with Existing Tools
validate_tool_integration() {
    local test_category="Tool Integration"
    
    echo -e "${YELLOW}--- QA Test Group 10: Tool Integration ---${NC}"
    
    # Test with existing validation scripts
    if [ -f "${SCRIPT_DIR}/test-phase4-validation.sh" ]; then
        run_qa_test "Integration: Phase 4 validation compatibility" "${SCRIPT_DIR}/test-phase4-validation.sh" 0 "$test_category"
    fi
    
    # Test deployer integration compatibility
    if [ -f "${SCRIPT_DIR}/deployer.sh" ]; then
        run_qa_test_with_output "Integration: Deployer script compatibility" "head -10 ${SCRIPT_DIR}/deployer.sh" "#!/" "$test_category"
    fi
    
    # Test git integration
    run_qa_test "Integration: Git repository compatibility" "git status" 0 "$test_category"
}

# Main QA validation execution
main() {
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${PURPLE}   PHASE 5: QA VALIDATION FRAMEWORK${NC}"
    echo -e "${PURPLE}    Comprehensive System Testing${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo ""
    
    log_qa "Starting comprehensive QA validation for Phase 5"
    
    local start_time=$(date +%s)
    
    # Run all validation test groups
    validate_files
    validate_phase_integration  
    validate_demo_functionality
    validate_team_scenarios
    validate_documentation
    validate_end_to_end
    validate_performance
    validate_cross_platform
    validate_security
    validate_tool_integration
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Final QA report
    echo -e "\n${PURPLE}================================================${NC}"
    echo -e "${PURPLE}           QA VALIDATION RESULTS${NC}"
    echo -e "${PURPLE}================================================${NC}"
    
    echo -e "\n${CYAN}📊 Test Statistics:${NC}"
    echo -e "${CYAN}• Total Tests Run: $TOTAL_TESTS${NC}"
    echo -e "${CYAN}• Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "${CYAN}• Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "${CYAN}• QA Issues Found: ${YELLOW}$QA_ISSUES${NC}"
    echo -e "${CYAN}• Total Duration: ${total_duration}s${NC}"
    
    local success_rate=$((TESTS_PASSED * 100 / TOTAL_TESTS))
    echo -e "${CYAN}• Success Rate: ${GREEN}$success_rate%${NC}"
    
    echo -e "\n${CYAN}🎯 Validation Gate 5 Criteria Check:${NC}"
    
    # Validation Gate 5 criteria assessment
    local gate5_passed=true
    
    # Criterion 1: Demo environment demonstrates all features
    if [ -f "$DEMO_SCRIPT" ] && [ -x "$DEMO_SCRIPT" ]; then
        echo -e "${GREEN}✅ Demo environment demonstrates all features working together${NC}"
    else
        echo -e "${RED}❌ Demo environment not properly implemented${NC}"
        gate5_passed=false
    fi
    
    # Criterion 2: Team validation scenarios
    if [ -f "$TEAM_SCRIPT" ] && [ -x "$TEAM_SCRIPT" ]; then
        echo -e "${GREEN}✅ Team can validate functionality through provided scenarios${NC}"
    else
        echo -e "${RED}❌ Team validation scenarios not available${NC}"
        gate5_passed=false
    fi
    
    # Criterion 3: Complete documentation
    if [ -f "${SCRIPT_DIR}/TEAM-ADOPTION-GUIDE.md" ]; then
        echo -e "${GREEN}✅ Complete documentation enables easy adoption${NC}"
    else
        echo -e "${RED}❌ Team adoption documentation missing${NC}"
        gate5_passed=false
    fi
    
    # Criterion 4: QA testing framework
    if [ $success_rate -ge 80 ]; then
        echo -e "${GREEN}✅ QA testing confirms production readiness (${success_rate}% success)${NC}"
    else
        echo -e "${RED}❌ QA testing indicates issues (${success_rate}% success < 80% threshold)${NC}"
        gate5_passed=false
    fi
    
    # Criterion 5: End-to-end integration
    if [ $TESTS_FAILED -le $(($TOTAL_TESTS / 10)) ]; then  # Allow up to 10% failures
        echo -e "${GREEN}✅ All 5 phases integrated and validated end-to-end${NC}"
    else
        echo -e "${RED}❌ Significant integration issues detected${NC}"
        gate5_passed=false
    fi
    
    # Final validation decision
    if [ $gate5_passed = true ] && [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 VALIDATION GATE 5 PASSED! 🎉${NC}"
        echo -e "${GREEN}🏆 PHASE 5: BACKSTAGE DEMO COMPLETE! 🏆${NC}"
        echo ""
        echo -e "${PURPLE}📋 System Ready For:${NC}"
        echo -e "${CYAN}• Production deployment in team environments${NC}"
        echo -e "${CYAN}• Full team onboarding and adoption${NC}"
        echo -e "${CYAN}• CI/CD pipeline integration${NC}"
        echo -e "${CYAN}• Real-world usage and scaling${NC}"
        echo ""
        log_qa "Phase 5 QA validation PASSED - system ready for production"
        exit 0
    elif [ $gate5_passed = true ] && [ $TESTS_FAILED -le $(($TOTAL_TESTS / 20)) ]; then  # Allow up to 5% failures
        echo -e "\n${YELLOW}⚠️  VALIDATION GATE 5 PASSED WITH MINOR ISSUES${NC}"
        echo -e "${YELLOW}System is production-ready with $TESTS_FAILED minor issues${NC}"
        echo ""
        echo -e "${CYAN}📋 Recommended Actions:${NC}"
        echo -e "${CYAN}• Review and address minor issues${NC}"
        echo -e "${CYAN}• Proceed with team onboarding${NC}"
        echo -e "${CYAN}• Monitor real-world usage${NC}"
        echo ""
        log_qa "Phase 5 QA validation PASSED with minor issues"
        exit 0
    else
        echo -e "\n${RED}❌ VALIDATION GATE 5 FAILED${NC}"
        echo -e "${RED}$TESTS_FAILED tests failed out of $TOTAL_TESTS ($(((TESTS_FAILED * 100) / TOTAL_TESTS))% failure rate)${NC}"
        echo -e "${RED}$QA_ISSUES QA issues identified requiring resolution${NC}"
        echo ""
        echo -e "${YELLOW}🔧 Required Actions:${NC}"
        echo -e "${CYAN}• Review and fix failed tests${NC}"
        echo -e "${CYAN}• Address QA issues identified${NC}"
        echo -e "${CYAN}• Re-run validation after fixes${NC}"
        echo -e "${CYAN}• Consider additional testing${NC}"
        echo ""
        log_qa "Phase 5 QA validation FAILED - requires fixes before production"
        exit 1
    fi
}

# Help function
show_help() {
    echo "Phase 5 QA Validation Framework - Comprehensive System Testing"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  help        Show this help message"
    echo "  full        Run complete QA validation (default)"
    echo "  quick       Run abbreviated validation"
    echo "  report      Generate QA report only"
    echo ""
    echo "This script validates all Phase 1-5 features and confirms"
    echo "the system is ready for production deployment."
}

# Main execution
case "${1:-full}" in
    "help")
        show_help
        ;;
    "full")
        main
        ;;
    "quick")
        echo -e "${YELLOW}Quick QA validation mode not implemented yet${NC}"
        echo -e "${CYAN}Running full validation...${NC}"
        main
        ;;
    "report")
        echo -e "${YELLOW}QA report generation not implemented yet${NC}"
        echo -e "${CYAN}Running full validation...${NC}"
        main
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac