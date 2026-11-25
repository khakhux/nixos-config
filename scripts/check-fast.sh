#!/usr/bin/env bash
set -euo pipefail

# Check only changed files: staged, unstaged, and untracked (relative to HEAD).
# Legacy hosts and experiments are intentionally outside the maintained scope.
repo_dir="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
cd "$repo_dir"

mapfile -d '' changed_files < <(
  git diff --name-only -z HEAD --
  git ls-files --others --exclude-standard -z
)

nix_files=()
shell_files=()
for file in "${changed_files[@]}"; do
  [[ -f "$file" ]] || continue
  case "$file" in
    flake.nix|ips.nix|ports.nix|users.nix|\
    hosts/currolaptop/*|hosts/mininas/*|hosts/minipc-n150/*|\
    modules/*|modules-dev/*|services/*|secrets/*|\
    scripts/*|dev-envs/java21/*)
      case "$file" in
        *.nix) nix_files+=("$file") ;;
        *.sh) shell_files+=("$file") ;;
      esac
      ;;
  esac
done

if ((${#nix_files[@]} == 0 && ${#shell_files[@]} == 0)); then
  echo "No changed maintained Nix or shell files."
  exit 0
fi

required_tools=()
if ((${#nix_files[@]})); then
  required_tools+=(nix-instantiate nixfmt)
fi
if ((${#shell_files[@]})); then
  required_tools+=(shellcheck)
fi
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    echo "Run with: nix shell --inputs-from . nixpkgs#nixfmt-rfc-style nixpkgs#shellcheck --command bash scripts/check-fast.sh" >&2
    exit 1
  fi
done

failed=0
for file in "${nix_files[@]}"; do
  echo "Parsing $file"
  nix-instantiate --parse "$file" >/dev/null || failed=1
  echo "Checking Nix formatting: $file"
  nixfmt --check "$file" || failed=1
done

for file in "${shell_files[@]}"; do
  echo "Checking shell syntax: $file"
  bash -n "$file" || failed=1
  echo "Linting shell: $file"
  shellcheck "$file" || failed=1
done

exit "$failed"
