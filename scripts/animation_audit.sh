#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_ROOT="$REPO_ROOT/Droppy"
REPORT="$REPO_ROOT/ANIMATION_AUDIT.md"

HITS_FILE="$(mktemp)"
RAW_FILE="$(mktemp)"
HARD_FILE="$(mktemp)"
trap 'rm -f "$HITS_FILE" "$RAW_FILE" "$HARD_FILE"' EXIT

find "$SRC_ROOT" -name '*.swift' -print0 | xargs -0 grep -nE \
  "withAnimation\\(|\\.animation\\(|\\.transition\\(|CAMediaTimingFunction\\(|matchedGeometryEffect\\(|\\.spring\\(|\\.smooth\\(|\\.bouncy\\(|\\.snappy\\(|\\.interactiveSpring\\(|\\.ease(In|Out|InOut)|\\.linear\\(" \
  > "$HITS_FILE"

grep -Ev "DroppyAnimation\\." "$HITS_FILE" > "$RAW_FILE" || true

awk '
  /^[[:space:]]*\/\// { next }
  /CAMediaTimingFunction\(|\.easeOut\(|\.easeInOut\(|\.linear\(|\.spring\(|\.smooth\(|\.interactiveSpring\(/ { print $0 }
' "$RAW_FILE" > "$HARD_FILE"

total_sites="$(wc -l < "$HITS_FILE" | tr -d ' ')"
raw_sites="$(wc -l < "$RAW_FILE" | tr -d ' ')"
ssot_sites="$((total_sites - raw_sites))"
hardcoded_sites="$(wc -l < "$HARD_FILE" | tr -d ' ')"
files_total="$(find "$SRC_ROOT" -name '*.swift' | wc -l | tr -d ' ')"
files_with_sites="$(awk -F: '{print $1}' "$HITS_FILE" | sort -u | wc -l | tr -d ' ')"
files_with_raw="$(awk -F: '{print $1}' "$RAW_FILE" | sort -u | wc -l | tr -d ' ')"

{
  echo "# Animation Audit"
  echo
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo
  echo "## Summary"
  echo
  echo "- Swift files scanned: $files_total"
  echo "- Files with animation usage: $files_with_sites"
  echo "- Files with raw (non-SSOT) animation usage: $files_with_raw"
  echo "- Total animation call sites: $total_sites"
  echo "- SSOT call sites (DroppyAnimation.*): $ssot_sites"
  echo "- Raw call sites: $raw_sites"
  echo "- Hardcoded primitive curve/timing sites: $hardcoded_sites"
  echo
  echo "## Raw Primitive Breakdown"
  echo
  echo "| Primitive | Count |"
  echo "|---|---:|"

  awk '
    { if ($0 ~ /CAMediaTimingFunction\(/) m["CAMediaTimingFunction("]++ }
    { if ($0 ~ /\.easeOut\(/) m[".easeOut("]++ }
    { if ($0 ~ /\.easeInOut\(/) m[".easeInOut("]++ }
    { if ($0 ~ /\.linear\(/) m[".linear("]++ }
    { if ($0 ~ /\.spring\(/) m[".spring("]++ }
    { if ($0 ~ /\.smooth\(/) m[".smooth("]++ }
    { if ($0 ~ /\.interactiveSpring\(/) m[".interactiveSpring("]++ }
    END {
      for (k in m) printf "%7d %s\n", m[k], k
    }
  ' "$HARD_FILE" | sort -nr | awk '{printf "| `%s` | %d |\n", $2, $1}'

  echo
  echo "## File Coverage"
  echo
  echo "| File | Sites | Raw | Status |"
  echo "|---|---:|---:|---|"

  while IFS= read -r file; do
    sites="$(grep -cF "$file:" "$HITS_FILE" || true)"
    raw="$(grep -cF "$file:" "$RAW_FILE" || true)"
    status="clean"
    if [[ "$sites" -gt 0 && "$raw" -eq 0 ]]; then
      status="ssot-only"
    elif [[ "$raw" -gt 0 && "$raw" -lt "$sites" ]]; then
      status="mixed"
    elif [[ "$raw" -gt 0 && "$sites" -eq "$raw" ]]; then
      status="raw-only"
    fi
    rel="${file#"$REPO_ROOT"/}"
    echo "| \`$rel\` | $sites | $raw | $status |"
  done < <(find "$SRC_ROOT" -name '*.swift' | sort)

  echo
  echo "## Top Raw Hotspots"
  echo
  echo "| File | Raw Sites |"
  echo "|---|---:|"
  awk -F: '{print $1}' "$RAW_FILE" | sort | uniq -c | sort -nr | head -n 40 | while read -r count file; do
    rel="${file#"$REPO_ROOT"/}"
    echo "| \`$rel\` | $count |"
  done

  echo
  echo "## Top Hardcoded Primitive Hotspots"
  echo
  echo "| File | Primitive Sites |"
  echo "|---|---:|"
  awk -F: '{print $1}' "$HARD_FILE" | sort | uniq -c | sort -nr | head -n 40 | while read -r count file; do
    rel="${file#"$REPO_ROOT"/}"
    echo "| \`$rel\` | $count |"
  done
} > "$REPORT"

echo "Wrote $REPORT"
