#!/bin/bash
# Adds out/ as a run-N folder on the "results" branch and pushes it. Used by the workflow.
#   RUN_NUMBER  folder suffix (default: GITHUB_RUN_NUMBER)
#   REMOTE      remote to publish to (default: origin)
set -euo pipefail
cd "$(dirname "$0")/.."

RUN_NUMBER="${RUN_NUMBER:-${GITHUB_RUN_NUMBER:?set RUN_NUMBER}}"
REMOTE="${REMOTE:-origin}"
WORKTREE="$(cd .. && pwd)/results-worktree"

if [ -z "$(ls -A out 2>/dev/null)" ]; then
  echo "nothing to publish"
  exit 0
fi

# ls-remote exits with 2 when the branch does not exist. Any other failure is a network problem, and treating
# that as "no branch yet" would start a new history and lose the earlier runs.
exists=unknown
for attempt in 1 2 3; do
  if git ls-remote --exit-code --heads "$REMOTE" results >/dev/null; then
    exists=yes
    break
  elif [ $? -eq 2 ]; then
    exists=no
    break
  fi
  echo "could not reach $REMOTE (attempt $attempt)"
  sleep 5
done

git worktree remove --force "$WORKTREE" 2>/dev/null || true
case "$exists" in
  yes)
    fetched=no
    for attempt in 1 2 3; do
      if git fetch --depth 1 "$REMOTE" results; then
        fetched=yes
        break
      fi
      echo "fetch of the results branch failed (attempt $attempt)"
      sleep 5
    done
    [ "$fetched" = yes ] || { echo "could not fetch the results branch; nothing was published"; exit 1; }
    git worktree add -B results "$WORKTREE" FETCH_HEAD
    ;;
  no)
    git worktree add --orphan -b results "$WORKTREE"
    ;;
  *)
    echo "could not check for the results branch; nothing was published"
    exit 1
    ;;
esac

mkdir -p "$WORKTREE/run-$RUN_NUMBER"
cp out/* "$WORKTREE/run-$RUN_NUMBER/"
git -C "$WORKTREE" add -A
git -C "$WORKTREE" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "Results for run $RUN_NUMBER ($(git rev-parse --short HEAD))"

for attempt in 1 2 3; do
  if git -C "$WORKTREE" push "$REMOTE" results; then
    echo "published run-$RUN_NUMBER"
    exit 0
  fi
  echo "push failed (attempt $attempt)"
  sleep 5
done
exit 1
