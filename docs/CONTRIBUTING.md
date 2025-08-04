# Contributing to Defold Deployer

Thank you for your interest in contributing to the Defold Deployer project!

## Development Workflow

### Branch Naming Convention
- `feature/description-of-feature` - For new features
- `fix/description-of-fix` - For bug fixes
- `chore/description-of-task` - For maintenance tasks
- `docs/description-of-docs` - For documentation updates

### Testing Changes
Before submitting changes:

1. Test the deployer script with various platforms
2. Use `test_spinner.sh` to test animation features if relevant
3. Ensure audio feedback works correctly on macOS
4. Test interrupt handling (Ctrl+C) during builds

### Audio Features
The deployer includes several audio features:
- **Tick Sound**: Morse.aiff plays during Bob builds
- **Success Sound**: Glass.aiff plays on successful operations  
- **Error Sound**: Basso.aiff plays on failed operations
- **Startup Sound**: Bottle.aiff plays when deployer starts

These require macOS system sounds and the `afplay` command.

### Code Style
- Use tabs for indentation in shell scripts
- Include comments for complex functionality
- Follow existing patterns for error handling and cleanup

### Commit Messages
Follow conventional commit format:
- `feat:` for new features
- `fix:` for bug fixes  
- `docs:` for documentation changes
- `test:` for adding tests
- `chore:` for maintenance tasks

## Pull Request Process

1. Create a feature/fix branch from `master`
2. Make your changes with appropriate tests
3. Update documentation if needed
4. Submit pull request with clear description
5. Ensure all tests pass

## Issues and Suggestions

- Use GitHub issues for bug reports and feature requests
- Include system information (macOS version, tools installed)
- Provide clear reproduction steps for bugs
