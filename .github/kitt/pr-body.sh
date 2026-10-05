# vendored from rbales79/kitt@1f0a6be929f75c48bd5c3cf61e0ba5b505007e52 tactics/plugin/checks/pr-body.sh by tools/adopt/adopt.sh; re-run it to update
# checks/pr-body.sh — the PR body names its issue, and never in a sentence GitHub would misread.
#   pr-body.sh < body      exit 0 ok · exit 1 with the reason on stdout
# The same script runs as the local hook (hooks/pr-check.sh) and in CI (.github/actions/pr-check).
set -u
body="$(cat)"
REF='(clos(e|es|ed)|fix(es|ed)?|resolv(e|es|ed)|updates?|refs?)[[:space:]]*:?[[:space:]]*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+'
NEG="(not|n't|never|nor)[[:space:]]+(clos(e|es)|fix(es)?|resolv(e|es))[[:space:]]*:?[[:space:]]*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+"
if printf '%s' "$body" | grep -qiE "$NEG"; then
  hit="$(printf '%s' "$body" | grep -oiE "$NEG" | head -1)"
  echo "The body says \"$hit\". GitHub reads the keyword and closes that issue anyway; the negation is invisible to it. Reword without the keyword, e.g. \"leaves #N open\"."
  exit 1
fi
if ! printf '%s' "$body" | grep -qiE "$REF"; then
  echo "The body names no issue. Every unit of work is a GitHub issue: carry \`Closes #<n>\` when the issue is finished or \`Updates #<n>\` when it is not."
  exit 1
fi
exit 0
