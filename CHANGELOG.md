# Changelog

All notable changes to `aprende` will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · SemVer.

## [Unreleased]

## [0.1.0] — 2026-05-11
### Added
- Initial release of the `aprende` skill / plugin.
- `/aprende` slash command with 5-pass workflow (scan → generate → dedup → confirm → execute).
- Four learning categories: `memory`, `lesson` (Reflexion-style anti-pattern), `skill` stub, `project-doc`.
- `/aprende --review` aging/pruning mode for lessons.
- `/aprende --portable` mirror to `./.aprende/` for cross-tool (Codex) workflows.
- `/learn` English alias.
- `PostToolUse` + `Stop` hooks (ON by default) for signal capture and end-of-session reminders.
- `/aprende enable-hooks` and `/aprende disable-hooks` commands.
- Dual-write to `CLAUDE.md` + `AGENTS.md` for cross-tool compatibility.
- 3 example fixtures with expected outputs.

[Unreleased]: https://github.com/Hainrixz/aprende-skill/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Hainrixz/aprende-skill/releases/tag/v0.1.0
