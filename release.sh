#!/usr/bin/env bash
# release.sh — cut a versioned release of FGX (kernel + userland + disk).
#
# Encodes docs/RELEASING.md so landing is ONE disciplined command.  `main`
# changes only through pull requests, so a release is a TWO-STEP: (1) gate +
# changelog + chore(release) commit, parked on a release/<v> branch with a pull
# request opened; (2) after the pull request merges (with a MERGE COMMIT, so the
# release commit itself is on main), `--tag <v>` pushes the annotated tag onto
# it, and the tag push makes CI publish the release image.
#
# Usage:
#   ./release.sh                          preview: suggested bump + unreleased commits (does nothing)
#   ./release.sh v0.11.0                  STEP 1: gate -> changelog -> chore commit -> push release/v0.11.0 -> open PR
#   ./release.sh --tag v0.11.0            STEP 2 (after the PR merges): push the v0.11.0 tag onto main
#   ./release.sh --auto                   step 1 at the git-cliff-suggested bump
#   ./release.sh --merge feat/x v0.11.0   fold feat/x into the release first (tags pre-x-merge)
#   ./release.sh v0.11.0 --no-push        stop before pushing the branch; --yes skips the prompt
# Flags: --no-gate, --abi changed|unchanged (tag annotation; default changed).
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

VERSION=""; MERGE=""; DO_GATE=1; DO_PUSH=1; ASSUME_YES=0; AUTO=0; ABI=changed; TAG_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    v[0-9]*)           VERSION="$1" ;;
    --tag)             TAG_ONLY=1 ;;
    --merge)           MERGE="${2:?--merge needs a branch}"; shift ;;
    --no-gate)         DO_GATE=0 ;;
    --no-push)         DO_PUSH=0 ;;
    --yes|-y)          ASSUME_YES=1 ;;
    --auto)            AUTO=1 ;;
    --abi)             ABI="${2:?}"; shift ;;
    -h|--help)         sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "release: unknown arg '$1' (try --help)" >&2; exit 2 ;;
  esac; shift
done

die(){ echo "release: $*" >&2; exit 1; }
note(){ printf '==> %s\n' "$*"; }

# --- STEP 2: --tag (push the release tag once its pull request has merged) ---
if [ "$TAG_ONLY" = 1 ]; then
  [ -n "$VERSION" ] || die "--tag needs a version (e.g. ./release.sh --tag v1.8.0)."
  case "$VERSION" in v[0-9]*.[0-9]*.[0-9]*) ;; *) die "version '$VERSION' must look like vX.Y.Z";; esac
  git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null \
    || die "no local tag $VERSION — run './release.sh $VERSION' first (it makes the tag + opens the pull request)."
  git fetch -q origin main 2>/dev/null || true
  TAGCOMMIT="$(git rev-parse "$VERSION^{commit}")"
  git merge-base --is-ancestor "$TAGCOMMIT" origin/main \
    || die "the $VERSION release commit is not on origin/main yet — merge the pull request with a merge commit, then re-run './release.sh --tag $VERSION'."
  note "pull request merged ($VERSION commit is on origin/main) — pushing tag"
  git push origin "$VERSION"
  git branch -D "release/$VERSION" 2>/dev/null && note "removed local branch release/$VERSION" || true
  git pull -q --ff-only origin main 2>/dev/null || true
  note "released $VERSION ✔"
  exit 0
fi

# --- preflight ---
git diff --quiet && git diff --cached --quiet || die "working tree dirty — commit or stash first."
[ "$(git branch --show-current)" = main ] || die "not on main (on '$(git branch --show-current)') — checkout main first."
git fetch -q origin main 2>/dev/null || true
LAST_TAG="$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null || true)"

# --- optional ff-merge of a feature branch ---
if [ -n "$MERGE" ]; then
  git rev-parse --verify -q "$MERGE" >/dev/null || die "branch '$MERGE' not found."
  git merge-base --is-ancestor HEAD "$MERGE" || die "main is not an ancestor of $MERGE — not a fast-forward."
  short="${MERGE##*/}"
  note "recovery tag pre-${short}-merge @ $(git rev-parse --short HEAD)"
  git tag -f "pre-${short}-merge" HEAD >/dev/null
  note "ff-merge $MERGE -> main"
  git merge --ff-only "$MERGE"
fi


# --- unreleased commits ---
RANGE="${LAST_TAG:+$LAST_TAG..}HEAD"
COMMITS="$(git log --oneline "$RANGE")"
[ -n "$COMMITS" ] || die "no commits since ${LAST_TAG:-the start} — nothing to release."
SUGGEST="$(git-cliff --bumped-version 2>/dev/null || echo '?')"

note "since ${LAST_TAG:-(initial)}:"; printf '%s\n' "$COMMITS" | sed 's/^/      /'
note "git-cliff suggests: $SUGGEST"

# --- resolve version / preview ---
if [ -z "$VERSION" ]; then
  if [ "$AUTO" = 1 ]; then
    [ "$SUGGEST" != "?" ] || die "git-cliff could not compute a bump — pass a version explicitly."
    VERSION="$SUGGEST"
  else
    note "preview only — re-run with a version (e.g. ./release.sh $SUGGEST) or --auto."
    exit 0
  fi
fi
case "$VERSION" in v[0-9]*.[0-9]*.[0-9]*) ;; *) die "version '$VERSION' must look like vX.Y.Z";; esac
git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null && die "tag $VERSION already exists."
note "releasing $VERSION"

# --- gate (must be green on the commit we will tag) ---
GATE="skipped"
if [ "$DO_GATE" = 1 ]; then
  # The gate does NOT run here.  It runs on push, in the background, and leaves
  # .gate/<sha>.json.  release.sh only asks whether THIS commit is green --
  # which is why a release stopped costing 36 minutes of foreground waiting.
  #
  # A MISSING receipt is treated exactly like a FAILED one.  "No status" reading
  # as "fine" is how the v1.13 net regression shipped behind a skipped gate.
  RECEIPT=".gate/$(git rev-parse HEAD).json"
  note "gate: checking receipt $RECEIPT"
  [ -f "$RECEIPT" ] || die "no gate receipt for $(git rev-parse --short HEAD) — run tools/gate.sh (a missing receipt is NOT a pass)."
  python3 - "$RECEIPT" <<'PYCHK' || die "gate receipt is not green — fix and re-run tools/gate.sh."
import json, sys
r = json.load(open(sys.argv[1]))
if not r.get("ok"):
    print(f"      receipt says FAILED: {r.get('why','?')}"); sys.exit(1)
# A build-only receipt does not attest that the OS BOOTS, which is the one
# behavioural claim the gate makes.  Everything else was deleted 2026-07-29.
if r.get("mode") != "smoke":
    print(f"      receipt is '{r.get('mode')}' — a RELEASE needs the smoke test (it proves the OS boots)")
    sys.exit(1)
for name in r.get("skipped", []):
    print(f"      NOT RUN: {name} (declared requirement unmet)")
print(f"      green: {r.get('result')} ({r.get('seconds')}s, {r.get('mode')})")
PYCHK
  # The tree must match what was gated: a receipt is for a commit AND its tree.
  TREE_NOW="$(git status --porcelain | shasum | cut -d' ' -f1)"
  python3 - "$RECEIPT" "$TREE_NOW" <<'PYCHK' || die "working tree differs from what was gated — re-run tools/gate.sh."
import json, sys
r = json.load(open(sys.argv[1]))
sys.exit(0 if r.get("tree") == sys.argv[2] else 1)
PYCHK
  GATE="receipt $(git rev-parse --short HEAD): smoke test green"
else
  note "GATE SKIPPED (--no-gate) — do NOT ship this."
fi

# --- changelog (delta-prepend, never full regen) ---
# CLIFF_EXTRA passes extra git-cliff args for THIS release only (unset by
# default, so the normal path is unchanged).  It exists for the one-off case
# where the range contains history already published elsewhere: the monorepo
# merge dragged in 990 fcc commits that had shipped under fcc's own
# v1.16.0-v1.24.0 tags in the archived apple/fcc, and rendering them as FGX's
# release notes would describe someone else's work as this release.
#   CLIFF_EXTRA="--exclude-path toolchain/**" ./release.sh v1.16.0
#
# `set -f` around the expansion is load-bearing: the value must word-split into
# separate args, but WITHOUT pathname expansion.  Unquoted and unguarded, the
# shell globs `toolchain/**` against the working tree and git-cliff receives a
# list of real files instead of the pattern -- which silently filtered almost
# nothing and produced a 10,668-line changelog section (vs 226 for v1.15.0).
note "changelog: git-cliff --unreleased --tag $VERSION --prepend ${CLIFF_EXTRA:-}"
set -f
# shellcheck disable=SC2086  # deliberate word-split of an arg list; glob disabled
git-cliff --unreleased --tag "$VERSION" ${CLIFF_EXTRA:-} --prepend CHANGELOG.md
set +f
# The README's download button names this version's image.
perl -pi -e 's#releases/download/v[0-9.]+/fgx-[0-9.]+\.po#releases/download/'"$VERSION"'/fgx-'"${VERSION#v}"'.po#g; s#Download `fgx-[0-9.]+\.po`#Download `fgx-'"${VERSION#v}"'.po`#g' README.md
grep -q "releases/download/$VERSION/fgx-${VERSION#v}.po" README.md \
  || die "README.md's download link was not updated to $VERSION"
git add CHANGELOG.md README.md
git commit -q -m "chore(release): $VERSION"

# --- annotated tag (created now on the release commit; PUSHED in step 2 once
#     the pull request has merged, so the tag never leads main) ---
TAGMSG="$VERSION — gate: ${GATE}; abi/layout: ${ABI} vs ${LAST_TAG:-initial}"
git tag -a "$VERSION" -m "$TAGMSG"
note "tagged (local, unpushed): $TAGMSG"

# --- publish through a pull request (main changes only through them) ---
# Park everything since origin/main (feature merge + chore commit) on
# release/$VERSION, keep local main tracking origin, push the branch, open
# the pull request.  The tag rides along in step 2 after merge.
REL_BRANCH="release/$VERSION"
git branch -f "$REL_BRANCH" HEAD
git reset --hard -q origin/main       # release commits live on $REL_BRANCH + the tag, not local main

if [ "$DO_PUSH" = 0 ]; then
  note "NOT pushing (--no-push).  Local: branch $REL_BRANCH + tag $VERSION."
  note "Finish:  git push -u origin $REL_BRANCH  (open a pull request)  then  ./release.sh --tag $VERSION"
  exit 0
fi
if [ "$ASSUME_YES" != 1 ]; then
  printf '==> push %s and open a release pull request into main ? [y/N] ' "$REL_BRANCH"; read -r a
  [ "$a" = y ] || [ "$a" = Y ] || { note "aborted before push — local branch + tag kept."; exit 0; }
fi
note "pushing $REL_BRANCH (the release lands through a pull request)"
git push -u origin "$REL_BRANCH"

# The description must say what the pull request actually LANDS and why — not just
# the version-bump mechanics (2026-07-16).  Pull the release's own
# changelog section (which carries the commit bodies) + the real commit list.
# Read CHANGELOG from $REL_BRANCH, NOT the working tree: the `git reset --hard
# origin/main` above moved the working tree back to origin (no [$VERSION]
# section), so awk'ing the working-tree CHANGELOG.md here yields an empty body.
CL_SECTION="$(git show "$REL_BRANCH:CHANGELOG.md" | awk -v v="${VERSION#v}" '
  $0 ~ "^## \\[" v "\\]" {f=1; next}  /^## \[/ {f=0}  f')"
LANDS="$(git log --oneline --no-decorate "origin/main..$REL_BRANCH")"
PR_DESC="Release **$VERSION** of FGX (kernel + userland + disk).

## What this pull request lands (origin/main..release/$VERSION)
\`\`\`
$LANDS
\`\`\`

## Changelog
$CL_SECTION

## Gate (ran locally — CI cannot boot MAME)
- ${GATE}
- abi/layout: ${ABI} vs ${LAST_TAG:-initial}

Merge with a merge commit (not squash or rebase), then run
\`./release.sh --tag $VERSION\` to push the annotated tag onto the release
commit; the tag push makes CI publish fgx-${VERSION#v}.po."
if command -v gh >/dev/null 2>&1; then
  gh pr create --head "$REL_BRANCH" --base main \
    --title "chore(release): FGX $VERSION" --body "$PR_DESC" 2>&1 | tail -3 \
    || note "gh pr create failed — open the pull request from the URL git printed above."
else
  note "gh not installed — open the pull request from the URL git printed above."
fi
note "release $VERSION staged.  MERGE THE PULL REQUEST (merge commit), then run:  ./release.sh --tag $VERSION"
