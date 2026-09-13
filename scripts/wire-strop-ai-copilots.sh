#!/usr/bin/env bash
# Wire tower + nested majordomo Cursor skills to strop ai-copilots.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/.majordomo/scripts/wire-strop-ai-copilots.sh"
MOD="$(cd "$ROOT/.majordomo" && go list -m -f '{{.Dir}}' github.com/behaviorengineering/strop)"
mkdir -p "$ROOT/.cursor/skills"
for name in strop-pipeline-pattern strop-orchestration strop-human-review; do
	ln -snf "$MOD/ai-copilots/skills/${name}" "$ROOT/.cursor/skills/${name}"
	test -f "$ROOT/.cursor/skills/${name}/SKILL.md"
done
echo "wired tower strop ai-copilots from $MOD"
