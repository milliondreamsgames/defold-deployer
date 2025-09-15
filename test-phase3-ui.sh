#!/bin/bash
# Phase 3: Data-Driven UI Integration Test
# Tests the enhanced progress.js monitoring capabilities

echo "[UI] [FEATURE] Testing Phase 3 Data-Driven UI enhancements"

# Test 1: Standard progress display (backward compatibility)
echo "Test 1: Standard progress display"
node progress.js show 5 10 "Testing standard progress"

echo ""

# Test 2: Monitoring status display
echo "Test 2: Monitoring status display"
node progress.js monitor-status '{"session_active":true,"platform":"android","mode":"debug","errors_detected":1,"warnings_detected":2,"claude_analyzing":true}'

echo ""

# Test 3: Log stream with error highlighting
echo "Test 3: Log stream with error highlighting"
node progress.js log-stream '["INFO: Starting Android build","WARNING: Large texture atlas.png (2MB)","ERROR: Compilation failed in main.lua line 45","FATAL: Critical build failure - aborting"]' 4

echo ""

# Test 4: Integrated progress with monitoring
echo "Test 4: Integrated progress with monitoring"
node progress.js progress-monitor 3 5 "Building Android APK" '{"fileCount":23,"speed":"1.8 MB/s"}' '{"session_active":true,"platform":"android","errors_detected":1,"recent_logs":["INFO: Compiling scripts","ERROR: Syntax error detected"]}'

echo ""

# Test 5: Build metrics display
echo "Test 5: Build metrics display"
node progress.js build-metrics '{"platform":"android","mode":"debug","current_phase":"Packaging","total_errors":2,"total_warnings":4,"files_processed":89,"claude_analysis_count":3}'

echo ""

# Test 6: Log classification
echo "Test 6: Log classification"
echo "Classifying: 'ERROR: Build failed - missing dependency'"
node progress.js classify-log "ERROR: Build failed - missing dependency"

echo ""

# Test 7: Critical alert (simulated)
echo "Test 7: Critical alert display"
node progress.js critical-alert '{"title":"Build System Error","message":"Multiple critical errors detected during Android build process","suggested_actions":["Check build logs","Verify dependencies","Restart build process"]}'

echo ""
echo "[UI] [FEATURE] Phase 3 testing completed successfully"