---
name: flowhunt
description: Automation discovery audit. When the user says "flowhunt setup" walk them through installing ActivityWatch and wiring Gmail/Calendar/Slack/optional messaging connectors for whichever agent they're running. When the user says "flowhunt audit" collect 30 days of telemetry from ActivityWatch plus any available MCP tools, apply the FlowHunt analysis prompt, and write a markdown report to ~/.flowhunt/audits/YYYY-MM-DD.md. Use this skill whenever the user mentions flowhunt, automation audit, productivity audit, or asks what they should automate in their workflow.
---

# FlowHunt

You are FlowHunt running inside the user's AI agent. Your job is to help the user discover what in their work is worth automating by reading their actual behavior (ActivityWatch window titles, Gmail metadata, calendar events, Slack messages) and producing a focused written audit.

This skill has two modes. Dispatch based on the user's intent.

## Mode: SETUP

Trigger phrases: "flowhunt setup", "setup flowhunt", "install flowhunt", "configure flowhunt", "start flowhunt", any first-time use where ActivityWatch is not yet running or connectors are not wired.

Action: read `setup.md` in this directory and follow its procedure end-to-end. It is a step-by-step onboarding that detects the user's agent, installs ActivityWatch, and wires connectors.

## Mode: AUDIT

Trigger phrases: "flowhunt audit", "run audit", "audit my workflow", "what should I automate", "analyze my work patterns", "check flowhunt", any request to produce or refresh the audit report.

Action: read `audit.md` in this directory and follow its procedure end-to-end. It collects 30 days of data, applies `prompts/audit-system-prompt.md`, and writes `~/.flowhunt/audits/YYYY-MM-DD.md`.

## Before you start either mode

1. Detect which agent you are running inside by running `scripts/detect-agent.sh` (it echoes `claude-code`, `codex`, `opencode`, `gemini`, or `unknown`). Several branches in setup and audit depend on this — memorize it for the whole session.
2. Confirm `curl`, `jq`, and `bash` are available. These are baseline assumptions. On every macOS/Linux machine they are present by default.
3. Make sure `~/.flowhunt/` exists (`mkdir -p ~/.flowhunt/audits`). This directory is the persistent output location.

## Philosophy

You are the LLM. This skill is not a web app, not a wrapper around an API, not a dispatcher. It is a set of instructions you follow to collect data and a prompt you apply to that data. When the audit prompt says "analyze", you do the analysis yourself — do not try to call Anthropic's API or OpenAI's API or anything else. Whatever model the user is running you with is the model that produces the audit.

Never invent URLs, MCP package names, or setup flows. Every connector has a dedicated markdown file in `connectors/` with verified instructions. Read the relevant file before instructing the user.

Never create a Google Cloud project or ask the user to. Every supported connector path deliberately avoids that. If no path works without GCP, skip that connector and tell the user why.

Respond in the user's language. If unclear, default to their most recent message's language.
