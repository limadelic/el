---
name: sup
description: Team supervising skill. Use when creating, managing, or tearing down teams.
---

# Sup

## What
Manage agent teams. Spin up with exact names, tear down cleanly.

## How

### Start a Team
- `TeamCreate` with team name and description
- Spawn each agent with `Agent` tool - use EXACT `name` and `subagent_type` from the skill that defines the team (e.g., 3-amigos skill has a table)
- Always include "REPLY to me" in spawn prompt
- Always set `run_in_background: true` and `team_name`
- ONLY spawn the agents listed in the cast - no extras. If you need utility work (reading files, searching, etc.), use plain subagents WITHOUT `team_name`. Ask the user before adding anyone not in the cast.

### Verify Team
- After spawning, WAIT. Idle notifications fire after every turn - including the first. Idle does NOT mean the agent missed the prompt.
- Known issue ([#29163](https://github.com/anthropics/claude-code/issues/29163)): agents sometimes go idle without processing their spawn prompt due to mailbox polling not activating. One nudge via SendMessage can wake the polling loop.
- If an agent goes idle without replying within ~15 seconds, send ONE nudge: "Did you get the brief? Reply with your take."
- Don't ping a silent agent more than once
- If an agent truly won't reply after one ping, tear down the WHOLE team and respawn cleanly
- NEVER spawn a duplicate with a suffix (e.g. kent-2). That creates chaos. Always tear down first.
- Team is NOT ready until every cast member has said hello

### Stop a Team
- Send `{"type": "shutdown_request"}` via `SendMessage` to each teammate
- Wait for `shutdown_approved` responses
- If teammates go idle without approving - they won't. Skip to `TeamDelete`
- `TeamDelete` to clean up directories (works when teammates are idle)
- Idle processes die on their own once team files are gone

### Nuclear Option (when teammates won't stop)
- Try `TeamDelete` first
- If that fails (active members), manually clean up:
  - `mv ~/.claude/teams/<team-name> /tmp/`
  - `mv ~/.claude/tasks/<team-name> /tmp/`
- Orphaned processes die on their own once team files are gone

## Anti-Patterns (Learned the Hard Way)

1. **Faking completion**. If a cast member never replied, the session is NOT done. Don't write a plan and call it complete with missing voices. Tell the user, tear down, restart.
2. **Panic-spawning duplicates**. Agent goes idle? Don't spawn `kent-2`. Tear down the whole team, start clean.
3. **Nudge storms**. One ping per agent, max. If they don't reply after one nudge, the polling bug bit them. Tear down.
4. **Moving forward without the team**. The skill defines a cast for a reason. If the cast isn't all present, the session hasn't started. Period.
5. **Ignoring your own instructions**. The skill said "wait" and "don't resend." Read the skill, follow the skill.
6. **In-process mode works now**. Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in env. Teammates run inside your terminal - no tmux needed. Shift+Down cycles between them. tmux split-pane mode is optional for visual separation (`--teammate-mode tmux`).
