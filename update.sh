
#!/usr/bin/env bash
set -euo pipefail

COMMIT_MESSAGE="Update flake inputs"

# Ensure we're in a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not inside a Git repository."
    exit 1
fi

# Ensure working tree is clean
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: Working tree is not clean."
    echo "Please commit or stash your changes first."
    exit 1
fi

# Ensure we're on a branch
BRANCH=$(git branch --show-current)
if [[ -z "$BRANCH" ]]; then
    echo "Error: Detached HEAD. Switch to a branch first."
    exit 1
fi

echo "Updating flake inputs..."
nix flake update

# Check whether anything changed
if git diff --quiet -- flake.lock; then
    echo "No flake updates available."
    exit 0
fi

echo
echo "Changes to flake.lock:"
git diff -- flake.lock

echo
read -r -p "Commit and push these changes? [y/N] " answer

if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Update left uncommitted."
    exit 0
fi

git add flake.lock
git commit -m "$COMMIT_MESSAGE"

echo "Pushing to origin/$BRANCH..."
git push origin "$BRANCH"

echo "Updating!"
nrs

echo
echo "Done! Flake inputs updated and pushed successfully."

