# CLAUDE.md — SimpleGLP

GLP-1 medication (shot) tracker (iOS). XcodeGen project/scheme: `SimpleGLP`,
simulator device `agent-simpleglp`.

Shared iOS conventions (build, simulator, release, review, signing, gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill. No app-specific overrides.

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.
