---
title: "Agent Guidance"
description: "Project-level guidance for agents working on magic-mac-menubar."
---

# Agent Guidance

Magic is a Swift menu bar app for macOS. Read [`ENGINEERING.md`](ENGINEERING.md)
before making changes and update it in the same change set when architecture,
decisions, verification status, or risks change.

## Topic Routing

Load the matching file before making decisions or edits in that topic:

| Topic | File to load |
| --- | --- |
| Git, branches, commits, or pull requests | [`agents/git.md`](agents/git.md) |
| Source code, scripts, or general coding practice | [`agents/coding.md`](agents/coding.md) |
| Markdown files or documentation authoring | [`agents/markdown.md`](agents/markdown.md) |
| Security or supply-chain security | [`agents/security.md`](agents/security.md) |
| Test strategy or test implementation | [`agents/testing.md`](agents/testing.md) |
| GitHub Actions workflows | [`agents/githubactions.md`](agents/githubactions.md) |
| Releases and change promotion | [`agents/release.md`](agents/release.md) |
| Dependency lifecycle | [`agents/dependencies.md`](agents/dependencies.md) |
| GNU Makefile | [`agents/makefile.md`](agents/makefile.md) |
| Bash or Zsh scripts | [`agents/shell.md`](agents/shell.md) |

## Project Rules

- Swift 6 toolchain, Swift 5 language mode; macOS 14+. Keep UI-free logic in
  `MagicCore` so it stays unit testable.
- Avoid `MainActor.assumeIsolated`; hop with `Task { @MainActor in ... }`.
- Validate with `make test`; lint with `make lint`.
- Do not commit third-party video downloads. Only `assets/magic.mp4` is tracked.
- Be concise; no `TODO` comments or placeholder logic.
