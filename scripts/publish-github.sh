#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

need_cmd git
need_cmd gh

REPO_NAME="${1:-wordpress-multi-docker}"
VISIBILITY="${2:-public}"

case "$VISIBILITY" in
  public|private) ;;
  *) fatal "Usage: $0 [repository-name] [public|private]" ;;
esac

cd "$REPO_ROOT"

gh auth status >/dev/null 2>&1 || fatal "GitHub CLI is not authenticated. Run: gh auth login"

if git remote get-url origin >/dev/null 2>&1; then
  fatal "An origin remote already exists: $(git remote get-url origin)"
fi

gh repo create "$REPO_NAME" "--$VISIBILITY" --source=. --remote=origin --push

echo "GitHub repository created and pushed."
