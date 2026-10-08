# vendored from rbales79/kitt@e6066637c685d0e46c54b3e6fbf5fb5fedc8c3f4 tactics/plugin/checks/docs-drift.sh by tools/adopt/adopt.sh; adopt.sh --refresh updates it
# checks/docs-drift.sh — docs land with the code that invalidates them.
#   docs-drift.sh <base-ref> [head-ref]   (run inside the repo) exit 0 clean · exit 1 with findings on stdout
# A finding: a changed file whose exact path a tracked .md names in a code span, where that .md is not in the
# diff. Advisory locally (the hook), a failing check in CI unless the PR carries the `docs-ok` label.
# It never edits: code is the source of truth on drift, but editing the doc to match can paper over a code
# regression, so a person decides which side is wrong.
#
# Dated records are not held to the code: a decision log, a spike report or an archive cites `path:line` as
# evidence of what was true when it was written, and rewriting it because the code later moved would falsify it.
# A repo lists them in .github/kitt/docs-drift.ignore — one path prefix or shell glob per line, `#` comments.
# (knowledge-forge, 2026-10-05: 11 of its last 30 merges would have failed, most on DECISIONS.md, spikes/, archive/.)
set -u
base="${1:?base ref}"; head="${2:-HEAD}"
# A Dependabot PR bumps a manifest to a fixed version; that never makes a document's prose stale (kitt#101).
if [ "${PR_AUTHOR:-}" = "dependabot[bot]" ]; then echo "dependabot[bot] PR: docs-check waived (kitt#101)"; exit 0; fi
case "${PR_AUTHOR:-}|${PR_HEAD:-}" in *"[bot]|renovate/"*) echo "Renovate PR ($PR_AUTHOR, $PR_HEAD): docs-check waived (kitt#141)"; exit 0;; esac
git rev-parse --verify -q "$base" >/dev/null || { echo "docs-drift: base ref '$base' not found"; exit 0; }
changed="$(git diff --name-only "$base...$head" 2>/dev/null)"
[ -n "$changed" ] || exit 0
docs="$(git ls-files '*.md' | grep -vE '^(tests?|node_modules|vendor)/|^docs/knowledge/')"
[ -n "$docs" ] || exit 0

ign=".github/kitt/docs-drift.ignore"
ignored() {  # ignored <path>: a dated record the repo exempts
  [ -f "$ign" ] || return 1
  local p
  while IFS= read -r p; do
    p="${p%%#*}"; p="$(printf '%s' "$p" | sed 's/[[:space:]]*$//; s/^[[:space:]]*//')"
    [ -n "$p" ] || continue
    case "$1" in $p|$p*) return 0;; esac
  done < "$ign"
  return 1
}

# One grep per document over every changed path, instead of one per (path, document) pair.
pat="$(mktemp)"; trap 'rm -f "$pat"' EXIT
printf '%s\n' "$changed" | grep -v '\.md$' | sed '/^$/d' | while IFS= read -r f; do printf '`%s`\n`%s:\n' "$f" "$f"; done > "$pat"
[ -s "$pat" ] || exit 0
stale=""
while IFS= read -r d; do
  [ -n "$d" ] || continue
  printf '%s\n' "$changed" | grep -qxF "$d" && continue
  ignored "$d" && continue
  hits="$(grep -ohF -f "$pat" "$d" 2>/dev/null | sed 's/^`//; s/`$//; s/:$//' | sort -u)"
  [ -n "$hits" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] && stale="$stale
  $d names \`$f\`"
  done <<HITS
$hits
HITS
done <<DOCS
$docs
DOCS
[ -n "$stale" ] || exit 0
echo "This change touches files that documents name, and those documents are not in the diff:$stale

Read each document. If the code is right, update the document in this PR; if the document is right, the code is the regression. Say which side is wrong. If neither needs to change, add the \`docs-ok\` label with a sentence in the PR body saying why. A dated record (a decision log, a spike report, an archive) belongs in .github/kitt/docs-drift.ignore."
exit 1
