# Claude Code Automated Log Monitoring System
## Installation and Deployment Guide

### 📋 Prerequisites

Before installing the Claude Code Automated Log Monitoring System, ensure you have:

- **Operating System**: macOS, Linux, or Windows with WSL
- **Bash**: Version 4.0 or later
- **Git**: For repository management
- **Defold**: Game engine with deployer setup
- **Node.js**: Version 16+ (optional, for webhook functionality)

### 🚀 Quick Installation

#### Method 1: Direct Installation (Recommended)

```bash
# 1. Clone or download the repository
git clone <repository-url> claude-monitoring
cd claude-monitoring

# 2. Make scripts executable
chmod +x claude-log-monitor.sh
chmod +x demo-phase5-backstage.sh
chmod +x team-validation-scenarios.sh
chmod +x test-phase5-validation.sh

# 3. Initialize the system
./claude-log-monitor.sh init

# 4. Validate installation
./claude-log-monitor.sh validate

# 5. Run demo to verify functionality
./demo-phase5-backstage.sh
```

#### Method 2: Copy to Existing Project

```bash
# Copy monitoring files to your existing Defold project
cp claude-log-monitor.sh /path/to/your/defold-project/
cp demo-phase5-backstage.sh /path/to/your/defold-project/
cp team-validation-scenarios.sh /path/to/your/defold-project/
cp test-phase5-validation.sh /path/to/your/defold-project/
cp TEAM-ADOPTION-GUIDE.md /path/to/your/defold-project/

cd /path/to/your/defold-project/
chmod +x *.sh
./claude-log-monitor.sh init
```

### 🔧 Configuration Setup

#### Basic Configuration

The system creates `.claude-monitors/config.json` automatically with sensible defaults:

```bash
# View current configuration
./claude-log-monitor.sh config show

# Set basic options
./claude-log-monitor.sh config set monitoring.enabled true
./claude-log-monitor.sh config set logging.level info
```

#### Webhook Configuration (Team Features)

**For Slack Integration:**
```bash
# Get webhook URL from Slack (Apps > Incoming Webhooks)
./claude-log-monitor.sh config set webhooks.providers.slack.url "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
./claude-log-monitor.sh config set webhooks.providers.slack.enabled true
./claude-log-monitor.sh config set webhooks.enabled true

# Test webhook
./claude-log-monitor.sh webhook test slack "Installation test message"
```

**For Discord Integration:**
```bash
# Get webhook URL from Discord (Server Settings > Integrations > Webhooks)
./claude-log-monitor.sh config set webhooks.providers.discord.url "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL"
./claude-log-monitor.sh config set webhooks.providers.discord.enabled true
./claude-log-monitor.sh config set webhooks.enabled true

# Test webhook
./claude-log-monitor.sh webhook test discord "Installation test message"
```

**For Microsoft Teams Integration:**
```bash
# Get webhook URL from Teams (Connectors > Incoming Webhook)
./claude-log-monitor.sh config set webhooks.providers.teams.url "https://outlook.office.com/webhook/YOUR/WEBHOOK/URL"
./claude-log-monitor.sh config set webhooks.providers.teams.enabled true
./claude-log-monitor.sh config set webhooks.enabled true

# Test webhook
./claude-log-monitor.sh webhook test teams "Installation test message"
```

### 🧪 Verification and Testing

#### 1. Run System Validation
```bash
# Comprehensive system validation
./test-phase5-validation.sh

# Quick validation
./claude-log-monitor.sh validate
```

#### 2. Demo Walkthrough
```bash
# Interactive demo of all features
./demo-phase5-backstage.sh

# Non-interactive validation
./demo-phase5-backstage.sh validate
```

#### 3. Team Scenarios
```bash
# Interactive team validation scenarios
./team-validation-scenarios.sh

# Specific scenario (e.g., new developer onboarding)
./team-validation-scenarios.sh menu
# Select option 1 for new developer onboarding
```

### 🏭 Production Deployment

#### Single Developer Setup

```bash
# 1. Install in your development environment
cd /path/to/your/defold/project
# Copy monitoring files (see Method 2 above)

# 2. Initialize and configure
./claude-log-monitor.sh init
./claude-log-monitor.sh config set monitoring.auto_start false

# 3. Test with a build
./claude-log-monitor.sh start android debug MyGame 1.0.0
./deployer.sh android  # Your existing build command
./claude-log-monitor.sh stop
```

#### Team Deployment

```bash
# 1. Set up shared configuration
./claude-log-monitor.sh config set team_features.shared_sessions true
./claude-log-monitor.sh config set team_features.knowledge_base true
./claude-log-monitor.sh config set team_features.performance_tracking true

# 2. Configure team webhooks (see Webhook Configuration above)

# 3. Populate knowledge base with common issues
./claude-log-monitor.sh team knowledge add "build error" "Check dependencies" "general"
./claude-log-monitor.sh team knowledge add "memory issue" "Review memory usage patterns" "general"

# 4. Train team members
# Each team member should run:
./team-validation-scenarios.sh
# Select option 1: New Developer Onboarding
```

#### CI/CD Pipeline Integration

**Jenkins Pipeline:**
```groovy
pipeline {
    agent any
    stages {
        stage('Setup Monitoring') {
            steps {
                sh './claude-log-monitor.sh init'
                sh './claude-log-monitor.sh start android release ${BUILD_NUMBER} ${BUILD_VERSION}'
            }
        }
        stage('Build') {
            steps {
                sh './deployer.sh android'
            }
        }
        stage('Cleanup') {
            post {
                always {
                    sh './claude-log-monitor.sh stop'
                    sh './claude-log-monitor.sh team metrics ${BUILD_NUMBER}'
                }
            }
        }
    }
}
```

**GitHub Actions:**
```yaml
name: Build with Monitoring
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Monitoring
        run: |
          chmod +x claude-log-monitor.sh
          ./claude-log-monitor.sh init
          ./claude-log-monitor.sh start android release ${{ github.run_number }} ${{ github.sha }}
      - name: Build
        run: ./deployer.sh android
      - name: Cleanup
        if: always()
        run: |
          ./claude-log-monitor.sh stop
          ./claude-log-monitor.sh team metrics ${{ github.run_number }}
```

**GitLab CI:**
```yaml
stages:
  - build

build_android:
  stage: build
  before_script:
    - chmod +x claude-log-monitor.sh
    - ./claude-log-monitor.sh init
    - ./claude-log-monitor.sh start android release $CI_PIPELINE_ID $CI_COMMIT_SHA
  script:
    - ./deployer.sh android
  after_script:
    - ./claude-log-monitor.sh stop
    - ./claude-log-monitor.sh team metrics $CI_PIPELINE_ID
```

### 🔒 Security Considerations

#### File Permissions
```bash
# Secure configuration directory
chmod 700 .claude-monitors/
chmod 600 .claude-monitors/config.json

# Secure webhook URLs (never commit to version control)
echo ".claude-monitors/config.json" >> .gitignore
```

#### Environment Variables (Alternative to config file)
```bash
# Set webhook URLs via environment variables
export CLAUDE_MONITOR_SLACK_WEBHOOK="https://hooks.slack.com/services/..."
export CLAUDE_MONITOR_DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
export CLAUDE_MONITOR_TEAMS_WEBHOOK="https://outlook.office.com/webhook/..."

# System will use environment variables if config values are empty
```

### 🚨 Troubleshooting

#### Common Installation Issues

**"Permission denied" errors:**
```bash
# Fix script permissions
chmod +x claude-log-monitor.sh
chmod +x demo-phase5-backstage.sh
chmod +x team-validation-scenarios.sh
chmod +x test-phase5-validation.sh
```

**"Config file not found":**
```bash
# Reinitialize the system
./claude-log-monitor.sh init
```

**"Bash version too old":**
```bash
# On macOS with Homebrew
brew install bash

# Update shebang in scripts to use newer bash
sed -i '' '1s|#!/bin/bash|#!/opt/homebrew/bin/bash|' *.sh
```

**Webhook test failures:**
```bash
# Check webhook URL configuration
./claude-log-monitor.sh config show | grep webhooks

# Test network connectivity
curl -X POST "YOUR_WEBHOOK_URL" -H "Content-Type: application/json" -d '{"text":"test"}'
```

#### Debugging Mode

```bash
# Enable debug logging
./claude-log-monitor.sh config set logging.level debug

# View debug logs
tail -f .claude-monitors/debug.log

# Check system status
./claude-log-monitor.sh status
```

### 📈 Performance Optimization

#### For Large Teams
```bash
# Optimize for multiple concurrent sessions
./claude-log-monitor.sh config set monitoring.session_timeout 7200  # 2 hours
./claude-log-monitor.sh config set logging.max_log_size "500MB"
./claude-log-monitor.sh config set logging.retention_days 60
```

#### For CI/CD Environments
```bash
# Optimize for automated builds
./claude-log-monitor.sh config set monitoring.auto_start true
./claude-log-monitor.sh config set webhooks.build_notifications.start false
./claude-log-monitor.sh config set webhooks.build_notifications.success true
./claude-log-monitor.sh config set webhooks.build_notifications.failure true
```

### 📊 Monitoring Health

#### System Health Check
```bash
# Daily health check script
#!/bin/bash
echo "Claude Monitor Health Check - $(date)"
./claude-log-monitor.sh validate
./claude-log-monitor.sh team status
./claude-log-monitor.sh reports list
echo "Health check complete"
```

#### Performance Metrics
```bash
# Weekly performance review
./claude-log-monitor.sh reports trend 7
./claude-log-monitor.sh team metrics summary
```

### 🆕 Updates and Maintenance

#### Updating the System
```bash
# Backup current configuration
cp .claude-monitors/config.json .claude-monitors/config.json.backup

# Update scripts (replace with new versions)
# Restore configuration
mv .claude-monitors/config.json.backup .claude-monitors/config.json

# Validate after update
./claude-log-monitor.sh validate
./test-phase5-validation.sh
```

#### Regular Maintenance
```bash
# Weekly maintenance script
#!/bin/bash
echo "Weekly maintenance - $(date)"

# Clean old logs
./claude-log-monitor.sh cleanup

# Validate system health
./claude-log-monitor.sh validate

# Update performance baselines
./claude-log-monitor.sh team metrics baseline-$(date +%Y%m%d)

echo "Maintenance complete"
```

---

## ✅ Installation Complete!

After completing this installation guide, you should have:

- ✅ **Fully functional monitoring system**
- ✅ **Team collaboration features configured**
- ✅ **Webhook notifications set up**
- ✅ **Validation and testing completed**
- ✅ **Production deployment ready**

### Next Steps

1. **Team Onboarding**: Run `./team-validation-scenarios.sh` for each team member
2. **CI/CD Integration**: Integrate with your build pipeline using the examples above
3. **Knowledge Base**: Start populating with real-world issues and solutions
4. **Performance Monitoring**: Establish baseline metrics and regular reporting

### Support

- **Documentation**: Read `TEAM-ADOPTION-GUIDE.md` for comprehensive usage
- **Demo**: Run `./demo-phase5-backstage.sh` anytime for feature demonstration
- **Validation**: Use `./test-phase5-validation.sh` to verify system health
- **Help**: Run `./claude-log-monitor.sh help` for command reference

**🎉 The Claude Code Automated Log Monitoring System is now ready for production use!**