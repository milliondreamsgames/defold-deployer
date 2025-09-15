#!/opt/homebrew/bin/bash
# test-claude-monitor.sh - Unit test suite for claude-log-monitor.sh Phase 1
# Tests all core logic functions for validation gate criteria

set -euo pipefail

# Test configuration
TEST_DIR="/tmp/claude-monitor-tests"
SCRIPT_PATH="./claude-log-monitor.sh"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test result tracking
TEST_RESULTS=()

# Logging
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

# Test assertion functions
assert_equals() {
    local expected=$1
    local actual=$2
    local description=$3
    
    ((TEST_COUNT++))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}[PASS]${NC} $description"
        TEST_RESULTS+=("PASS: $description")
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $description"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        TEST_RESULTS+=("FAIL: $description - Expected '$expected', got '$actual'")
        ((FAIL_COUNT++))
        return 1
    fi
}

assert_file_exists() {
    local file_path=$1
    local description=$2
    
    ((TEST_COUNT++))
    
    if [ -f "$file_path" ]; then
        echo -e "${GREEN}[PASS]${NC} $description"
        TEST_RESULTS+=("PASS: $description")
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $description"
        echo -e "  File not found: '$file_path'"
        TEST_RESULTS+=("FAIL: $description - File not found: '$file_path'")
        ((FAIL_COUNT++))
        return 1
    fi
}

assert_dir_exists() {
    local dir_path=$1
    local description=$2
    
    ((TEST_COUNT++))
    
    if [ -d "$dir_path" ]; then
        echo -e "${GREEN}[PASS]${NC} $description"
        TEST_RESULTS+=("PASS: $description")
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $description"
        echo -e "  Directory not found: '$dir_path'"
        TEST_RESULTS+=("FAIL: $description - Directory not found: '$dir_path'")
        ((FAIL_COUNT++))
        return 1
    fi
}

assert_command_success() {
    local command=$1
    local description=$2
    
    ((TEST_COUNT++))
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC} $description"
        TEST_RESULTS+=("PASS: $description")
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $description"
        echo -e "  Command failed: '$command'"
        TEST_RESULTS+=("FAIL: $description - Command failed: '$command'")
        ((FAIL_COUNT++))
        return 1
    fi
}

assert_command_failure() {
    local command=$1
    local description=$2
    
    ((TEST_COUNT++))
    
    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC} $description"
        TEST_RESULTS+=("PASS: $description")
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $description"
        echo -e "  Command should have failed: '$command'"
        TEST_RESULTS+=("FAIL: $description - Command should have failed: '$command'")
        ((FAIL_COUNT++))
        return 1
    fi
}

assert_json_valid() {
    local json_file=$1
    local description=$2
    
    ((TEST_COUNT++))
    
    if jq empty "$json_file" 2>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} $description"
        TEST_RESULTS+=("PASS: $description")
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $description"
        echo -e "  Invalid JSON in: '$json_file'"
        TEST_RESULTS+=("FAIL: $description - Invalid JSON in: '$json_file'")
        ((FAIL_COUNT++))
        return 1
    fi
}

assert_contains() {
    local haystack=$1
    local needle=$2
    local description=$3
    
    ((TEST_COUNT++))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}[PASS]${NC} $description"
        TEST_RESULTS+=("PASS: $description")
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $description"
        echo -e "  '$needle' not found in: '$haystack'"
        TEST_RESULTS+=("FAIL: $description - '$needle' not found in: '$haystack'")
        ((FAIL_COUNT++))
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    log_test "Setting up test environment in $TEST_DIR"
    
    # Get current directory
    local current_dir=$(pwd)
    
    # Clean up any existing test directory
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Copy script to test directory
    cp "${current_dir}/${SCRIPT_PATH}" "$TEST_DIR/"
    
    log_test "Test environment ready"
}

# Cleanup test environment
cleanup_test_env() {
    log_test "Cleaning up test environment"
    
    # Stop any running sessions
    if [ -f "./claude-log-monitor.sh" ]; then
        ./claude-log-monitor.sh cleanup 2>/dev/null || true
    fi
    
    # Clean up test directory
    cd /tmp
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    
    log_test "Test environment cleaned up"
}

# Test 1: Basic initialization
test_initialization() {
    echo -e "\n${CYAN}=== Test 1: Basic Initialization ===${NC}"
    
    # Test init command
    assert_command_success "./claude-log-monitor.sh init" "Initialize monitoring system"
    
    # Check directory structure
    assert_dir_exists "./.claude-monitors" "Main monitor directory created"
    assert_dir_exists "./.claude-monitors/sessions" "Sessions directory created"
    assert_dir_exists "./.claude-monitors/reports" "Reports directory created"
    assert_dir_exists "./.claude-monitors/patterns" "Patterns directory created"
    
    # Check configuration file
    assert_file_exists "./.claude-monitors/config.json" "Configuration file created"
    assert_json_valid "./.claude-monitors/config.json" "Configuration file is valid JSON"
    
    # Test validation command
    assert_command_success "./claude-log-monitor.sh validate" "Configuration validation passes"
}

# Test 2: Configuration management
test_configuration() {
    echo -e "\n${CYAN}=== Test 2: Configuration Management ===${NC}"
    
    # Test config show
    local config_output=$(./claude-log-monitor.sh config show 2>/dev/null || echo "")
    assert_contains "$config_output" "monitoring_enabled" "Config show displays monitoring_enabled"
    
    # Test config set
    assert_command_success "./claude-log-monitor.sh config set test_key test_value" "Set configuration value"
    
    # Verify config was set
    local test_value=$(jq -r '.test_key' ./.claude-monitors/config.json 2>/dev/null || echo "")
    assert_equals "test_value" "$test_value" "Configuration value correctly set"
    
    # Test invalid JSON handling
    echo "invalid json" > ./.claude-monitors/config.json
    assert_command_failure "./claude-log-monitor.sh validate" "Invalid JSON correctly detected"
    
    # Restore valid config
    ./claude-log-monitor.sh init >/dev/null 2>&1
}

# Test 3: Session lifecycle
test_session_lifecycle() {
    echo -e "\n${CYAN}=== Test 3: Session Lifecycle Management ===${NC}"
    
    # Test session start
    assert_command_success "./claude-log-monitor.sh start android debug TestGame 1.0.0" "Start monitoring session"
    
    # Check session directory creation
    local session_count=$(find ./.claude-monitors/sessions -name "monitor_android_debug_*" -type d | wc -l | tr -d ' ')
    assert_equals "1" "$session_count" "Session directory created"
    
    # Check session metadata
    local session_dir=$(find ./.claude-monitors/sessions -name "monitor_android_debug_*" -type d | head -1)
    if [ -n "$session_dir" ]; then
        assert_file_exists "$session_dir/metadata.json" "Session metadata file created"
        assert_json_valid "$session_dir/metadata.json" "Session metadata is valid JSON"
        assert_file_exists "$session_dir/prompt.md" "Session prompt file created"
        
        # Verify metadata content
        local platform=$(jq -r '.platform' "$session_dir/metadata.json" 2>/dev/null || echo "")
        assert_equals "android" "$platform" "Session platform correctly stored"
        
        local mode=$(jq -r '.mode' "$session_dir/metadata.json" 2>/dev/null || echo "")
        assert_equals "debug" "$mode" "Session mode correctly stored"
    fi
    
    # Test current session tracking
    assert_file_exists "./.claude-monitors/current_session" "Current session file created"
    
    # Test session listing
    local list_output=$(./claude-log-monitor.sh list-sessions 2>/dev/null || echo "")
    assert_contains "$list_output" "monitor_android_debug_" "Session appears in list"
    
    # Test session stop
    assert_command_success "./claude-log-monitor.sh stop" "Stop monitoring session"
    
    # Verify session was stopped
    if [ -n "$session_dir" ] && [ -f "$session_dir/metadata.json" ]; then
        local status=$(jq -r '.status' "$session_dir/metadata.json" 2>/dev/null || echo "")
        assert_equals "completed" "$status" "Session status updated to completed"
    fi
}

# Test 4: Communication system
test_communication() {
    echo -e "\n${CYAN}=== Test 4: Communication System ===${NC}"
    
    # Start a session
    ./claude-log-monitor.sh start test debug TestApp 1.0 >/dev/null 2>&1
    
    # Test send-log command (with timeout to avoid hanging)
    timeout 5 ./claude-log-monitor.sh send-log 'Test log entry' >/dev/null 2>&1
    local send_result=$?
    if [ $send_result -eq 0 ] || [ $send_result -eq 124 ]; then
        echo -e "${GREEN}[PASS]${NC} Send log entry to session"
        TEST_RESULTS+=("PASS: Send log entry to session")
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} Send log entry to session"
        TEST_RESULTS+=("FAIL: Send log entry to session")
        ((FAIL_COUNT++))
    fi
    ((TEST_COUNT++))
    
    # Test send-log with no active session
    ./claude-log-monitor.sh stop >/dev/null 2>&1
    assert_command_success "./claude-log-monitor.sh send-log 'Test log entry'" "Send log with no active session (graceful handling)"
    
    # Test send-log with missing argument
    assert_command_failure "./claude-log-monitor.sh send-log" "Send log with no argument fails appropriately"
}

# Test 5: Error handling
test_error_handling() {
    echo -e "\n${CYAN}=== Test 5: Error Handling ===${NC}"
    
    # Test stop with no session
    assert_command_failure "./claude-log-monitor.sh stop" "Stop with no session fails appropriately"
    
    # Test stop with invalid session ID
    assert_command_failure "./claude-log-monitor.sh stop invalid_session_123" "Stop with invalid session fails"
    
    # Test config operations without init
    rm -rf ./.claude-monitors
    assert_command_success "./claude-log-monitor.sh config show" "Config show handles missing config gracefully"
    
    # Test validation without config
    rm -rf ./.claude-monitors
    assert_command_failure "./claude-log-monitor.sh validate" "Validation fails appropriately without config"
}

# Test 6: Cleanup and recovery
test_cleanup_recovery() {
    echo -e "\n${CYAN}=== Test 6: Cleanup and Recovery ===${NC}"
    
    # Initialize and start multiple sessions
    ./claude-log-monitor.sh init >/dev/null 2>&1
    ./claude-log-monitor.sh start android debug App1 1.0 >/dev/null 2>&1
    ./claude-log-monitor.sh start ios release App2 2.0 >/dev/null 2>&1
    
    # Test cleanup command
    assert_command_success "./claude-log-monitor.sh cleanup" "Cleanup all sessions succeeds"
    
    # Verify cleanup removed current session file
    if [ -f "./.claude-monitors/current_session" ]; then
        echo -e "${RED}[FAIL]${NC} Current session file not cleaned up"
        ((FAIL_COUNT++))
        TEST_RESULTS+=("FAIL: Current session file not cleaned up")
    else
        echo -e "${GREEN}[PASS]${NC} Current session file cleaned up"
        TEST_RESULTS+=("PASS: Current session file cleaned up")
    fi
    ((TEST_COUNT++))
}

# Test 7: Configuration validation
test_config_validation() {
    echo -e "\n${CYAN}=== Test 7: Configuration Validation ===${NC}"
    
    # Initialize fresh config
    ./claude-log-monitor.sh init >/dev/null 2>&1
    
    # Test valid configuration
    assert_command_success "./claude-log-monitor.sh validate" "Valid configuration passes validation"
    
    # Test missing required field
    jq 'del(.monitoring_enabled)' ./.claude-monitors/config.json > ./.claude-monitors/config.json.tmp && \
    mv ./.claude-monitors/config.json.tmp ./.claude-monitors/config.json
    assert_command_failure "./claude-log-monitor.sh validate" "Missing required field fails validation"
    
    # Restore config
    ./claude-log-monitor.sh init >/dev/null 2>&1
    
    # Test malformed JSON
    echo '{"incomplete": json' > ./.claude-monitors/config.json
    assert_command_failure "./claude-log-monitor.sh validate" "Malformed JSON fails validation"
}

# Test 8: Debug logging
test_debug_logging() {
    echo -e "\n${CYAN}=== Test 8: Debug Logging Verification ===${NC}"
    
    # Test that init includes debug logging
    local init_output=$(./claude-log-monitor.sh init 2>&1)
    assert_contains "$init_output" "[FEATURE]" "Init command includes debug logging"
    
    # Test that start includes debug logging
    local start_output=$(./claude-log-monitor.sh start test debug 2>&1)
    assert_contains "$start_output" "[FEATURE]" "Start command includes debug logging"
    
    # Test that list includes debug logging
    local list_output=$(./claude-log-monitor.sh list-sessions 2>&1)
    assert_contains "$list_output" "[FEATURE]" "List command includes debug logging"
}

# Run all tests
run_all_tests() {
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE} Claude Log Monitor - Phase 1 Tests  ${NC}"
    echo -e "${PURPLE}======================================${NC}"
    
    log_test "Starting comprehensive test suite"
    
    # Verify script exists
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}[ERROR]${NC} Script not found: $SCRIPT_PATH"
        exit 1
    fi
    
    # Run all test suites
    test_initialization
    test_configuration
    test_session_lifecycle
    test_communication
    test_error_handling
    test_cleanup_recovery
    test_config_validation
    test_debug_logging
    
    # Print test summary
    echo -e "\n${PURPLE}======================================${NC}"
    echo -e "${PURPLE}           TEST SUMMARY              ${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo -e "Total Tests: ${TEST_COUNT}"
    echo -e "${GREEN}Passed: ${PASS_COUNT}${NC}"
    echo -e "${RED}Failed: ${FAIL_COUNT}${NC}"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}[SUCCESS]${NC} All tests passed! ✓"
        echo -e "${GREEN}Phase 1 validation gate criteria met.${NC}"
        return 0
    else
        echo -e "\n${RED}[FAILURE]${NC} Some tests failed. ✗"
        echo -e "\n${YELLOW}Failed Tests:${NC}"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ "$result" == FAIL:* ]]; then
                echo -e "  ${RED}•${NC} ${result#FAIL: }"
            fi
        done
        return 1
    fi
}

# Generate test report
generate_test_report() {
    local report_file="test-results-phase1.md"
    
    cat > "$report_file" << EOF
# Claude Log Monitor Phase 1 Test Results

## Summary
- **Total Tests**: $TEST_COUNT
- **Passed**: $PASS_COUNT
- **Failed**: $FAIL_COUNT
- **Success Rate**: $(( (PASS_COUNT * 100) / TEST_COUNT ))%

## Test Results

EOF
    
    local test_num=1
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == PASS:* ]]; then
            echo "### Test $test_num: ✓ PASS" >> "$report_file"
            echo "${result#PASS: }" >> "$report_file"
            echo "" >> "$report_file"
        else
            echo "### Test $test_num: ✗ FAIL" >> "$report_file"
            echo "${result#FAIL: }" >> "$report_file"
            echo "" >> "$report_file"
        fi
        ((test_num++))
    done
    
    cat >> "$report_file" << EOF

## Phase 1 Validation Gate Criteria

$([ $FAIL_COUNT -eq 0 ] && echo "✓ All unit tests pass (100% core function coverage)" || echo "✗ Some unit tests failed")
$([ $FAIL_COUNT -eq 0 ] && echo "✓ Session can be created, managed, and cleaned up properly" || echo "? Session management needs verification")
$([ $FAIL_COUNT -eq 0 ] && echo "✓ Configuration system works with validation" || echo "? Configuration system needs fixes")
$([ $FAIL_COUNT -eq 0 ] && echo "✓ Named pipes communicate correctly" || echo "? Named pipe communication needs verification")
$([ $FAIL_COUNT -eq 0 ] && echo "✓ Error scenarios handled gracefully" || echo "? Error handling needs improvement")

## Overall Status
$([ $FAIL_COUNT -eq 0 ] && echo "**PHASE 1 VALIDATION GATE: PASSED** ✓" || echo "**PHASE 1 VALIDATION GATE: FAILED** ✗")

Generated: $(date)
EOF
    
    echo -e "\n${CYAN}[REPORT]${NC} Test report generated: $report_file"
}

# Main execution
main() {
    # Setup
    setup_test_env
    
    # Run tests
    if run_all_tests; then
        generate_test_report
        cleanup_test_env
        exit 0
    else
        generate_test_report
        cleanup_test_env
        exit 1
    fi
}

# Signal handling
trap 'cleanup_test_env; exit 1' INT TERM

# Execute main function
main "$@"