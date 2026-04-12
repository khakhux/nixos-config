#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/update-opencode.sh [--host HOSTNAME] [--rebuild]

Options:
  --host HOSTNAME  NixOS flake host (default: currolaptop)
  --rebuild        Run nixos-rebuild switch after updating lock input
  -h, --help       Show this help message
EOF
}

HOST="currolaptop"
REBUILD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: --host needs a value" >&2
        exit 1
      fi
      HOST="$1"
      ;;
    --rebuild)
      REBUILD=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_DIR}"

expr=".#nixosConfigurations.${HOST}.config._module.args.pkgsUnstable.opencode.version"

echo "Checking current opencode version for host '${HOST}'..."
OLD_VERSION="$(nix eval --raw "$expr")"
echo "Current version: ${OLD_VERSION}"

echo "Updating nixpkgs-unstable input..."
nix flake lock --update-input nixpkgs-unstable

NEW_VERSION="$(nix eval --raw "$expr")"
echo "New version: ${NEW_VERSION}"

if [[ "${NEW_VERSION}" == "${OLD_VERSION}" ]]; then
  echo "No opencode update found in current nixpkgs-unstable."
else
  echo "opencode updated: ${OLD_VERSION} -> ${NEW_VERSION}"
fi

if [[ "${REBUILD}" == true ]]; then
  echo "Applying system switch for host '${HOST}'..."
  sudo nixos-rebuild switch --flake ".#${HOST}"
fi
