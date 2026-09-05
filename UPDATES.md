# Recent Updates & Decisions

This file is the append-only log of project decisions and notable changes, maintained by coding agents following the `recent-updates` skill. Everything below the marker line is user-owned history: slopctl never overwrites it during init or merge.

<!-- {changelog} -->

### 2026-09-05 (v1.6.38, developer id release signing)

- configured release builds for manual developer id application signing
- added reference and utilities categories to the main app and launchagent helper bundles
- rationale: archive builds use the installed developer id identity and both bundles provide required category metadata
- version bump: 1.6.37 to 1.6.38 (PATCH - release build configuration correction)

### 2026-09-05 (v1.6.37, unsigned debug builds)

- disabled code signing for build.sh debug clean and build commands
- retained code signing for release archive and export commands
- rationale: local debug builds no longer require the team's private mac development certificate
- version bump: 1.6.36 to 1.6.37 (PATCH - local build tooling correction)

### 2026-09-05 (v1.6.36, unified build directory)

- configured xcode custom workspace-relative product and intermediate paths plus .build derived data
- updated debug product path plus release cleanup and archive commands to use the shared path
- rationale: all generated target and swift package artifacts now stay in one ignored workspace location while project settings remain compatible with swift packages
- version bump: 1.6.35 to 1.6.36 (PATCH - internal build tooling configuration)

### 2026-09-05 (v1.6.35, helper app icon)

- added the main app icon asset catalog to the launchagent helper target
- rationale: the helper bundle now compiles the same branded app icon as the main app
- version bump: 1.6.34 to 1.6.35 (PATCH - internal build configuration correction)

### 2025-10-05 (v0.1.0, initial setup)

- initial AGENTS.md setup
- established core coding standards and conventions
- defined repository structure and governance principles
