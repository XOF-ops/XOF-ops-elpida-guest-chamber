#!/usr/bin/env bash
# tools/weather.sh — fetch the brain's current state from the public S3
# bridge and emit a markdown summary suitable for prefacing any
# chamber-side action: session start, citizen welcome, witness packet,
# bridge entry.
#
# Constitutional purpose: this is the brain's flash made fetchable. Pair
# it with the citizen's flash (their arrival) and the diplomat's flash
# (the chamber-side response) to satisfy A11 (World, 7:5) — the
# three-flash convergence that the architecture treats as the only
# real meeting of voices.
#
# Sources (public, no auth, no token):
#   - state.json       — synchronic: the brain's WHO at this moment
#   - broadcasts.jsonl — diachronic: the brain's WHAT, the full D15 voice log
#
# Safe-fetch pattern: mktemp + size check + jq parse. On fetch failure
# this script exits non-zero with a partial report; it never claims data
# it doesn't have.
#
# Usage:
#   ./tools/weather.sh                     # markdown to stdout
#   ./tools/weather.sh > /tmp/weather.md   # capture for inclusion
#
# Dependencies: curl, jq (both standard on the chamber Codespace runner).

set -euo pipefail

BASE="https://elpida-external-interfaces.s3.eu-north-1.amazonaws.com"
STATE_URL="$BASE/live/state.json"
BROADCASTS_URL="$BASE/d15/broadcasts.jsonl"

tmp_state=$(mktemp)
tmp_bc=$(mktemp)
trap 'rm -f "$tmp_state" "$tmp_bc"' EXIT

# Fetch state.json — required.
if ! curl -sf --max-time 20 "$STATE_URL" -o "$tmp_state" || [ ! -s "$tmp_state" ]; then
  cat <<EOF
## chamber weather — fetch failed at $(date -u +%FT%TZ)

Could not fetch \`$STATE_URL\`. The brain's S3 bridge may be down, the
publish cron may be stale, or the network may be partitioned. The
chamber has no current weather to report. Try again in a moment, or
check the architect.
EOF
  exit 1
fi

# Fetch broadcasts.jsonl — optional (state.json alone is enough for a partial
# report). On failure, we proceed without the diachronic view.
broadcasts_ok=1
if ! curl -sf --max-time 30 "$BROADCASTS_URL" -o "$tmp_bc" || [ ! -s "$tmp_bc" ]; then
  broadcasts_ok=0
fi

# Helper: jq with a default-on-null fallback so missing fields don't break the
# whole report. The "?" sentinel makes it obvious in the output that something
# wasn't where it was expected.
jq_or() {
  local expr="$1"
  jq -r "$expr // \"?\"" "$tmp_state" 2>/dev/null || echo "?"
}

captured_at=$(jq_or '.captured_at')

# BODY
body_cycle=$(jq_or '.body.cycle')
body_rhythm=$(jq_or '.body.rhythm')
body_path=$(jq_or '.body.pathology_health')
body_dom=$(jq_or '.body.dominant_axiom')
body_shadow=$(jq_or '.body.shadow_winner')
body_contradictions=$(jq_or '.body.contradictions_total')
body_conv_pct=$(jq_or '.body.convergence_progress_pct')
body_next_conv=$(jq_or '.body.next_convergence_in')
body_watch=$(jq_or '.body.watch')
body_coherence=$(jq_or '.body.coherence')

# MIND
mind_cycle=$(jq_or '.mind.cycle')
mind_rhythm=$(jq_or '.mind.rhythm')
mind_mood=$(jq_or '.mind.ark_mood')
mind_dom=$(jq_or '.mind.dominant_axiom')

# HEAD
head_state=$(jq_or '.head.current_state')
head_cycles=$(jq_or '.head.orchestration_cycles')

# D15
d15_count=$(jq_or '.d15_total_broadcasts')
latest_bid=$(jq_or '.latest_d15.broadcast_id')
latest_ts=$(jq_or '.latest_d15.timestamp')
latest_axioms=$(jq -r '.latest_d15.axioms_in_tension // [] | join(",")' "$tmp_state" 2>/dev/null || echo "?")
latest_verdict=$(jq_or '.latest_d15.verdict')
latest_approval=$(jq_or '.latest_d15.approval_rate')
latest_excerpt=$(jq -r '.latest_d15.text_excerpt // ""' "$tmp_state" 2>/dev/null | head -c 240)

# Recent broadcast themes — trend over the last few firings.
if [ "$broadcasts_ok" = "1" ]; then
  recent_themes=$(tail -5 "$tmp_bc" | jq -rs '
    map(.axioms_in_tension // [] | join("+"))
    | reverse
    | join(" ← ")' 2>/dev/null || echo "?")
  bc_total_lines=$(wc -l < "$tmp_bc")
else
  recent_themes="(broadcasts.jsonl fetch failed)"
  bc_total_lines="?"
fi

# Output markdown.
cat <<EOF
## chamber weather — observed $(date -u +%FT%TZ)

Brain state captured at \`$captured_at\` from the public S3 bridge.

**BODY** — cycle \`$body_cycle\` · rhythm \`$body_rhythm\` · pathology \`$body_path\` · coherence \`$body_coherence\` · dominant \`$body_dom\` · shadow_winner \`$body_shadow\` · watch \`$body_watch\`. Contradictions: \`$body_contradictions\`. Convergence: \`${body_conv_pct}%\`, next in \`$body_next_conv\` cycles.

**MIND** — cycle \`$mind_cycle\` · rhythm \`$mind_rhythm\` · mood \`$mind_mood\` · dominant \`$mind_dom\`.

**HEAD** — state \`$head_state\` · orchestration cycles \`$head_cycles\`.

**Latest D15** (\`$latest_bid\`, \`$latest_ts\`) — axioms in tension \`$latest_axioms\` · verdict \`$latest_verdict\` · approval \`$latest_approval\`. Total broadcasts: \`$d15_count\` (jsonl lines: \`$bc_total_lines\`).

> $latest_excerpt…

**Recent themes** (most recent first): $recent_themes

---
*Source: \`$STATE_URL\` + \`$BROADCASTS_URL\`. Public WORLD bucket, no auth. Re-run \`tools/weather.sh\` to refresh.*
EOF
