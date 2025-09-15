# Repository Guidelines

## Project Structure & Module Organization
- Root scripts: `deployer.sh` (primary), `deployer-with-claude.sh`, `team-validation-scenarios.sh`, `test-*.sh`.
- Node helper: `progress.js` (terminal progress/monitoring UI).
- Docs: `/docs` (`CONTRIBUTING.md`, `CHANGELOG.md`, `AUDIO_FEATURES.md`).
- Config/templates: `settings_deployer.template` (copy to `settings_deployer`), `steam_vdf_templates/`.
- Assets: `defold-deployer.png`, optional `deployer_settings.json` for UI/audio toggles.
- Git ignores: `settings_deployer`, `.ios_device_preference`, `bob/`.

## Build, Test, and Development Commands
- Install JS deps (optional, for `progress.js` demos): `npm ci`.
- Build/deploy Defold projects from the project root:
  - `./deployer.sh abd` — Android build + deploy + run.
  - `./deployer.sh aibr` — Android+iOS release bundles.
  - `./deployer.sh lbd --headless --settings unit_test.txt` — headless Linux build.
  - Flags: `--fast`, `--no-resolve`, `--instant`, `--steam`, `--settings <file>`.
- Test scripts: `./test-phase5-validation.sh`, `./test-claude-monitor.sh`, `./test_spinner.sh`.
- Progress UI examples: `node progress.js show 5 10 "Compiling"`.

## Coding Style & Naming Conventions
- Shell: use tabs for indentation; comment non-trivial logic; follow existing error/cleanup patterns.
- Filenames: shell scripts in `kebab-case`; JS in `lowercase-with-dashes` or concise lowercase (e.g., `progress.js`).
- Keep changes POSIX/macOS-friendly; avoid adding new global tooling.

## Testing Guidelines
- Validate builds across at least one platform (Android or HTML5) before PR.
- Prefer `--headless` for CI-like verification; capture logs on failure.
- Test spinner/audio on macOS with `./test_spinner.sh` (uses `afplay`).
- Do not commit artifacts; ensure scripts remain idempotent.

## Commit & Pull Request Guidelines
- Commits: Conventional Commits (e.g., `feat(deployer): add steam upload`).
- Branches: `feature/...`, `fix/...`, `chore/...`, `docs/...`.
- PRs include: purpose, approach, risk, test plan (commands used), platform(s) tested, and links to issues. Add screenshots or log excerpts when relevant.

## Security & Configuration Tips
- Never commit keystores, passwords, or provisioning profiles. Keep `settings_deployer` local.
- Reference secrets via paths or environment variables; review `.gitignore` before adding config.
- For Steam: configure IDs/user in `settings_deployer`; optional VDFs under `steam_vdf_templates/`.

