#!/usr/bin/env bash
set -euo pipefail

EXT="$1"

case "$EXT" in
  yaml) FILE_EXT="yaml" ;;
  dotenv) FILE_EXT="properties" ;;
  *) FILE_EXT="$EXT" ;;
esac

REPO_ROOT=$(git rev-parse --show-toplevel)
TMPFILE=$(mktemp "${REPO_ROOT}/.sops-smudge-XXXXXX.${FILE_EXT}")
ERRFILE=$(mktemp /tmp/sops-err-XXXXXX.txt)
trap "rm -f '$TMPFILE' '$ERRFILE'" EXIT

has_sops_payload() {
  case "$EXT" in
    yaml)
      grep -qE "^[[:space:]]*sops[[:space:]]*:" "$TMPFILE"
      ;;
    dotenv)
      grep -qE "^[[:space:]]*sops_" "$TMPFILE"
      ;;
    *)
      grep -qE "ENC\[|^[[:space:]]*sops[[:space:]]*:" "$TMPFILE"
      ;;
  esac
}

cat > "$TMPFILE"

if ! has_sops_payload 2>/dev/null; then
  cat "$TMPFILE"
  exit 0
fi

if sops --decrypt --input-type "$EXT" --output-type "$EXT" "$TMPFILE" 2>"$ERRFILE"; then
  :
elif grep -qE "no encrypted values|file is not encrypted|sops metadata not found|cannot parse" "$ERRFILE"; then
  cat "$TMPFILE"
else
  cat "$ERRFILE" >&2
  exit 1
fi