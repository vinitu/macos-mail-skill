# Repo Guide

This repository provides a skill for Apple Mail.app integration on macOS.
It enables reading, composing, searching, and organizing emails through a stable JSON-based command-line interface.
The skill is designed for automation and integration with AI agents.

## Goal
- Provide an accurate and stable public command layer for Mail.app.
- Return structured JSON for all read and write operations.
- Treat email data as private user data and ensure safety boundaries.

## Repository Layout
- `scripts/commands/`: **Public Interface**. Stable shell wrappers. Use these only.
- `scripts/applescripts/`: **Internal Backend**. AppleScript entrypoints. Do not call directly.
- `tests/`: Automated and smoke tests for the public contract.
- `SKILL.md`: Detailed usage instructions and JSON contracts for agents.
- `README.md`: Installation and human-facing overview.

## Public Rule
- **Always** use `scripts/commands/...` from the repository root.
- **Never** call `scripts/applescripts/...` directly.

## Validation
After making changes, run these commands to ensure everything is correct:
- `make check`: Verify dependencies (Mail.app, `jq`).
- `make compile`: Syntax check for all AppleScript files.
- `make test`: Run all contract and smoke tests.

## Safety Rules
- Treat all email data as real user data.
- Never send or reply to messages without explicit user approval.
- Prefer creating drafts (`create.sh`) over direct sending (`send.sh`).
