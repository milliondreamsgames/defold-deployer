// Enhanced progress display with statistics and beautiful formatting
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
            
        default:
            console.log('Usage: node progress.js [command] [args...]');
            console.log('Commands:');
            console.log('  show <step> <total> <message> [stats_json] - Show progress bar with optional stats');
            console.log('  files <current> <total> <filename> [bytes_per_sec] - Show file processing progress');
            console.log('  message <text> - Show timestamped message');
            console.log('  success <text> - Show success message');
            console.log('  error <text> - Show error message');
            console.log('  warning <text> - Show warning message');
            console.log('');
            console.log('Examples:');
            console.log('  node progress.js show 5 10 "Compiling files"');
            console.log('  node progress.js files 123 500 "main.cpp" 2048000');
            console.log('  node progress.js message "Starting build process"');
            break;
    }
}

