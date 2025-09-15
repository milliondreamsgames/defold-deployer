// Enhanced progress display with statistics and beautiful formatting
// Phase 3: Data-Driven UI - Added monitoring status integration
function showProgress(step, total, message, stats = {}) {
    const percentage = Math.round((step / total) * 100);
    const progressChars = Math.round((step / total) * 40); // Wider progress bar
    
    // Enhanced progress bar with gradient effect
    const fullBlocks = '█'.repeat(Math.floor(progressChars));
    const partialBlock = progressChars % 1 > 0 ? '▓' : '';
    const emptyBlocks = '░'.repeat(40 - Math.ceil(progressChars));
    const bar = fullBlocks + partialBlock + emptyBlocks;
    
    // Color coding based on percentage
    let colorCode = '\x1b[91m'; // Red for low progress
    if (percentage >= 25) colorCode = '\x1b[93m'; // Yellow for medium
    if (percentage >= 50) colorCode = '\x1b[96m'; // Cyan for good
    if (percentage >= 75) colorCode = '\x1b[92m'; // Green for high
    if (percentage >= 100) colorCode = '\x1b[95m'; // Magenta for complete
    
    // Build statistics display
    let statsDisplay = '';
    if (stats.fileCount) {
        statsDisplay += ` | ${stats.fileCount} files`;
    }
    if (stats.speed) {
        statsDisplay += ` | ${stats.speed}`;
    }
    if (stats.eta) {
        statsDisplay += ` | ETA: ${stats.eta}`;
    }
    
    // Clear the line and show enhanced progress
    process.stdout.write('\r\x1b[K'); // Clear current line
    process.stdout.write(`${colorCode}[${bar}] ${percentage}%\x1b[0m${statsDisplay} | ${message}`);
    
    if (step >= total) {
        process.stdout.write('\n'); // New line when complete
    }
}

// Real-time file processing progress with dynamic stats
function showFileProgress(currentFile, totalFiles, filename, bytesPerSecond = 0) {
    const percentage = Math.round((currentFile / totalFiles) * 100);
    const progressChars = Math.round((currentFile / totalFiles) * 35);
    
    // Speed formatting
    let speedDisplay = '';
    if (bytesPerSecond > 0) {
        if (bytesPerSecond > 1048576) { // MB/s
            speedDisplay = `${(bytesPerSecond / 1048576).toFixed(1)} MB/s`;
        } else if (bytesPerSecond > 1024) { // KB/s
            speedDisplay = `${(bytesPerSecond / 1024).toFixed(1)} KB/s`;
        } else {
            speedDisplay = `${bytesPerSecond} B/s`;
        }
    }
    
    // Truncate filename if too long
    const maxFilenameLength = 25;
    const displayFilename = filename.length > maxFilenameLength 
        ? '...' + filename.slice(-maxFilenameLength + 3)
        : filename;
    
    const bar = '█'.repeat(progressChars) + '░'.repeat(35 - progressChars);
    
    process.stdout.write('\r\x1b[K');
    process.stdout.write(`\x1b[96m[${bar}] ${percentage}%\x1b[0m | ${currentFile}/${totalFiles} | ${speedDisplay} | ${displayFilename}`);
    
    if (currentFile >= totalFiles) {
        process.stdout.write('\n');
    }
}

// Phase 3: Data-Driven UI Enhancement - Monitoring Integration

// Error pattern detection and classification
function classifyLogEntry(logLine) {
    const patterns = {
        critical: [
            /FATAL|Fatal|fatal/,
            /ERROR.*failed.*build/i,
            /Exception.*build/i,
            /BUILD FAILED/i,
            /compilation.*failed/i,
            /deployment.*failed/i
        ],
        error: [
            /ERROR|Error/,
            /Exception/,
            /Failed to/i,
            /Could not/i,
            /Unable to/i,
            /not found/i
        ],
        warning: [
            /WARNING|Warning/,
            /deprecated/i,
            /missing/i,
            /skipping/i,
            /performance/i
        ],
        info: [
            /INFO|Info/,
            /Starting/i,
            /Completed/i,
            /Building/i,
            /Deploying/i
        ]
    };

    for (const [level, regexList] of Object.entries(patterns)) {
        for (const regex of regexList) {
            if (regex.test(logLine)) {
                return {
                    level: level,
                    timestamp: new Date().toISOString(),
                    original: logLine,
                    pattern: regex.source
                };
            }
        }
    }

    return {
        level: 'debug',
        timestamp: new Date().toISOString(),
        original: logLine,
        pattern: 'unclassified'
    };
}

// Real-time monitoring status display
function showMonitoringStatus(monitoringData = {}) {
    const {
        session_active = false,
        platform = 'unknown',
        mode = 'unknown',
        errors_detected = 0,
        warnings_detected = 0,
        claude_analyzing = false,
        last_event_time = null
    } = monitoringData;

    // Monitoring status indicator
    const statusColor = session_active ? '\x1b[92m' : '\x1b[90m';
    const statusIcon = session_active ? '●' : '○';
    const claudeIcon = claude_analyzing ? '🧠' : '  ';
    
    // Error/warning summary
    let alertDisplay = '';
    if (errors_detected > 0) {
        alertDisplay += ` \x1b[91m❌${errors_detected}\x1b[0m`;
    }
    if (warnings_detected > 0) {
        alertDisplay += ` \x1b[93m⚠️ ${warnings_detected}\x1b[0m`;
    }
    
    // Time since last activity
    let activityDisplay = '';
    if (last_event_time) {
        const timeDiff = Math.floor((Date.now() - new Date(last_event_time).getTime()) / 1000);
        activityDisplay = ` | ${timeDiff}s ago`;
    }

    process.stdout.write(`${statusColor}[${statusIcon} MONITOR]${claudeIcon}\x1b[0m ${platform}/${mode}${alertDisplay}${activityDisplay}\n`);
}

// Enhanced log streaming display with error highlighting
function showLogStream(logEntries, maxLines = 5) {
    if (!Array.isArray(logEntries) || logEntries.length === 0) {
        return;
    }

    console.log('\x1b[36m[📜 LOG STREAM]\x1b[0m');
    
    // Show most recent entries
    const recentEntries = logEntries.slice(-maxLines);
    
    recentEntries.forEach(entry => {
        const classified = typeof entry === 'string' ? classifyLogEntry(entry) : entry;
        const timestamp = new Date(classified.timestamp).toLocaleTimeString();
        
        let colorCode = '\x1b[37m'; // Default gray
        let icon = '  ';
        
        switch (classified.level) {
            case 'critical':
                colorCode = '\x1b[91m'; // Bright red
                icon = '🔥';
                break;
            case 'error':
                colorCode = '\x1b[31m'; // Red  
                icon = '❌';
                break;
            case 'warning':
                colorCode = '\x1b[33m'; // Yellow
                icon = '⚠️ ';
                break;
            case 'info':
                colorCode = '\x1b[96m'; // Cyan
                icon = 'ℹ️ ';
                break;
        }
        
        // Truncate long log lines
        const maxLength = 80;
        const displayText = classified.original.length > maxLength 
            ? classified.original.substring(0, maxLength - 3) + '...'
            : classified.original;
            
        console.log(`${colorCode}[${timestamp}] ${icon} ${displayText}\x1b[0m`);
    });
}

// Integrated progress display with monitoring data
function showProgressWithMonitoring(step, total, message, stats = {}, monitoringData = {}) {
    // Show standard progress
    showProgress(step, total, message, stats);
    
    // Add monitoring status below progress bar
    if (monitoringData && Object.keys(monitoringData).length > 0) {
        showMonitoringStatus(monitoringData);
    }
    
    // Show recent log activity if available
    if (monitoringData.recent_logs && monitoringData.recent_logs.length > 0) {
        showLogStream(monitoringData.recent_logs, 3);
    }
}

// Performance metrics with error tracking
function showBuildMetrics(buildData = {}) {
    const {
        platform = 'unknown',
        mode = 'unknown',
        start_time = null,
        current_phase = 'unknown',
        total_errors = 0,
        total_warnings = 0,
        files_processed = 0,
        claude_analysis_count = 0
    } = buildData;

    const elapsed = start_time ? Math.floor((Date.now() - new Date(start_time).getTime()) / 1000) : 0;
    const minutes = Math.floor(elapsed / 60);
    const seconds = elapsed % 60;
    const timeDisplay = minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;

    console.log('\x1b[96m[📊 BUILD METRICS]\x1b[0m');
    console.log(`Platform: ${platform} | Mode: ${mode} | Elapsed: ${timeDisplay}`);
    console.log(`Phase: ${current_phase} | Files: ${files_processed}`);
    
    if (total_errors > 0 || total_warnings > 0) {
        console.log(`Issues: \x1b[91m${total_errors} errors\x1b[0m, \x1b[93m${total_warnings} warnings\x1b[0m`);
    }
    
    if (claude_analysis_count > 0) {
        console.log(`Claude Analysis: ${claude_analysis_count} AI insights generated`);
    }
}

// Visual notification for critical events
function showCriticalAlert(alertData = {}) {
    const {
        title = 'Critical Event',
        message = 'Unknown critical event occurred',
        suggested_actions = [],
        timestamp = new Date().toISOString()
    } = alertData;

    console.log('\x1b[91m');
    console.log('╔═══════════════════════════════════════════════════════════════════════════════╗');
    console.log('║                                 🚨 CRITICAL ALERT 🚨                         ║');
    console.log('╠═══════════════════════════════════════════════════════════════════════════════╣');
    console.log(`║ ${title.padEnd(77)} ║`);
    console.log(`║ Time: ${new Date(timestamp).toLocaleString().padEnd(69)} ║`);
    console.log('╠═══════════════════════════════════════════════════════════════════════════════╣');
    
    // Word wrap message
    const words = message.split(' ');
    let currentLine = '';
    
    words.forEach(word => {
        if ((currentLine + word).length > 75) {
            console.log(`║ ${currentLine.padEnd(77)} ║`);
            currentLine = word + ' ';
        } else {
            currentLine += word + ' ';
        }
    });
    
    if (currentLine.trim()) {
        console.log(`║ ${currentLine.trim().padEnd(77)} ║`);
    }
    
    if (suggested_actions.length > 0) {
        console.log('╠═══════════════════════════════════════════════════════════════════════════════╣');
        console.log('║ Suggested Actions:                                                           ║');
        suggested_actions.slice(0, 3).forEach((action, index) => {
            const actionText = `${index + 1}. ${action}`;
            if (actionText.length > 75) {
                console.log(`║ ${actionText.substring(0, 75).padEnd(77)} ║`);
                console.log(`║    ${actionText.substring(75).padEnd(74)} ║`);
            } else {
                console.log(`║ ${actionText.padEnd(77)} ║`);
            }
        });
    }
    
    console.log('╚═══════════════════════════════════════════════════════════════════════════════╝');
    console.log('\x1b[0m');
}

// Command line interface with enhanced options
if (require.main === module) {
    const args = process.argv.slice(2);
    const command = args[0];
    
    switch (command) {
        case 'show':
            const step = parseInt(args[1]) || 0;
            const total = parseInt(args[2]) || 10;
            const message = args[3] || 'Processing...';
            const statsJson = args[4];
            let stats = {};
            if (statsJson) {
                try {
                    stats = JSON.parse(statsJson);
                } catch (e) {
                    // Ignore JSON parse errors
                }
            }
            showProgress(step, total, message, stats);
            break;
        
        case 'files':
            const currentFile = parseInt(args[1]) || 0;
            const totalFiles = parseInt(args[2]) || 1;
            const filename = args[3] || 'unknown';
            const bytesPerSecond = parseInt(args[4]) || 0;
            showFileProgress(currentFile, totalFiles, filename, bytesPerSecond);
            break;
            
        case 'message':
            const msg = args[1] || 'Working...';
            const timestamp = new Date().toLocaleTimeString();
            console.log(`\x1b[36m[${timestamp}]\x1b[0m ${msg}`);
            break;
            
        case 'success':
            const successMsg = args[1] || 'Operation completed successfully';
            console.log(`\x1b[32m[✅ SUCCESS]\x1b[0m ${successMsg}`);
            break;
            
        case 'error':
            const errorMsg = args[1] || 'Operation failed';
            console.log(`\x1b[31m[❌ ERROR]\x1b[0m ${errorMsg}`);
            break;
            
        case 'warning':
            const warningMsg = args[1] || 'Warning occurred';
            console.log(`\x1b[33m[⚠️  WARNING]\x1b[0m ${warningMsg}`);
            break;
            
        // Phase 3: Data-Driven UI - New monitoring commands
        case 'monitor-status':
            const monitorDataJson = args[1];
            let monitorData = {};
            if (monitorDataJson) {
                try {
                    monitorData = JSON.parse(monitorDataJson);
                } catch (e) {
                    console.error('Error parsing monitoring data JSON');
                }
            }
            showMonitoringStatus(monitorData);
            break;
            
        case 'log-stream':
            const logEntriesJson = args[1];
            const maxLines = parseInt(args[2]) || 5;
            let logEntries = [];
            if (logEntriesJson) {
                try {
                    logEntries = JSON.parse(logEntriesJson);
                } catch (e) {
                    console.error('Error parsing log entries JSON');
                }
            }
            showLogStream(logEntries, maxLines);
            break;
            
        case 'progress-monitor':
            const progressStep = parseInt(args[1]) || 0;
            const progressTotal = parseInt(args[2]) || 10;
            const progressMessage = args[3] || 'Processing...';
            const progressStatsJson = args[4];
            const progressMonitoringDataJson = args[5];
            
            let progressStats = {};
            let progressMonitoringData = {};
            
            if (progressStatsJson) {
                try { progressStats = JSON.parse(progressStatsJson); } catch (e) {}
            }
            if (progressMonitoringDataJson) {
                try { progressMonitoringData = JSON.parse(progressMonitoringDataJson); } catch (e) {}
            }
            
            showProgressWithMonitoring(progressStep, progressTotal, progressMessage, progressStats, progressMonitoringData);
            break;
            
        case 'build-metrics':
            const buildDataJson = args[1];
            let buildData = {};
            if (buildDataJson) {
                try {
                    buildData = JSON.parse(buildDataJson);
                } catch (e) {
                    console.error('Error parsing build data JSON');
                }
            }
            showBuildMetrics(buildData);
            break;
            
        case 'critical-alert':
            const alertDataJson = args[1];
            let alertData = {};
            if (alertDataJson) {
                try {
                    alertData = JSON.parse(alertDataJson);
                } catch (e) {
                    console.error('Error parsing alert data JSON');
                }
            }
            showCriticalAlert(alertData);
            break;
            
        case 'classify-log':
            const logLine = args[1] || 'Sample log entry';
            const classification = classifyLogEntry(logLine);
            console.log(JSON.stringify(classification, null, 2));
            break;
            
        default:
            console.log('Usage: node progress.js [command] [args...]');
            console.log('');
            console.log('Standard Commands:');
            console.log('  show <step> <total> <message> [stats_json] - Show progress bar with optional stats');
            console.log('  files <current> <total> <filename> [bytes_per_sec] - Show file processing progress');
            console.log('  message <text> - Show timestamped message');
            console.log('  success <text> - Show success message');
            console.log('  error <text> - Show error message');
            console.log('  warning <text> - Show warning message');
            console.log('');
            console.log('Phase 3: Monitoring Commands:');
            console.log('  monitor-status [monitoring_data_json] - Show real-time monitoring status');
            console.log('  log-stream <log_entries_json> [max_lines] - Display log stream with error highlighting');
            console.log('  progress-monitor <step> <total> <message> [stats_json] [monitoring_data_json] - Combined progress and monitoring');
            console.log('  build-metrics [build_data_json] - Show build performance metrics');
            console.log('  critical-alert [alert_data_json] - Display critical event alert');
            console.log('  classify-log <log_line> - Classify log entry by error pattern');
            console.log('');
            console.log('Standard Examples:');
            console.log('  node progress.js show 5 10 "Compiling files"');
            console.log('  node progress.js files 123 500 "main.cpp" 2048000');
            console.log('  node progress.js message "Starting build process"');
            console.log('');
            console.log('Monitoring Examples:');
            console.log('  node progress.js monitor-status \'{"session_active":true,"platform":"android","errors_detected":2}\'');
            console.log('  node progress.js log-stream \'["ERROR: Build failed","WARNING: Deprecated API"]\'');
            console.log('  node progress.js progress-monitor 3 10 "Building" \'{}\' \'{"session_active":true}\'');
            console.log('  node progress.js build-metrics \'{"platform":"android","total_errors":1,"elapsed_time":45}\'');
            console.log('  node progress.js critical-alert \'{"title":"Build Failed","message":"Compilation error in main.lua"}\'');
            console.log('  node progress.js classify-log "ERROR: Failed to compile main.lua"');
            break;
    }
}

