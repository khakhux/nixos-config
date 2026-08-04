#!/usr/bin/env bash
set -euo pipefail

EXT="$1"

# Map extension to proper file extension for SOPS path matching
case "$EXT" in
    yaml) FILE_EXT="yaml" ;;
    dotenv) FILE_EXT="properties" ;;
    *) FILE_EXT="$EXT" ;;
esac

REPO_ROOT=$(git rev-parse --show-toplevel)
TMPFILE=$(mktemp "${REPO_ROOT}/.sops-smudge-XXXXXX.${FILE_EXT}")
ERRFILE=$(mktemp /tmp/sops-err-XXXXXX.txt)
trap "rm -f '$TMPFILE' '$ERRFILE'" EXIT

cat > "$TMPFILE"

if ! grep -qE "_enc[=:]" "$TMPFILE" 2>/dev/null; then
    # No encrypted keys - pass through unchanged
    cat "$TMPFILE"
    exit 0
fi

if sops --decrypt --input-type "$EXT" --output-type "$EXT" "$TMPFILE" 2>"$ERRFILE"; then
    : # sops writes to stdout directly, nothing extra needed
elif grep -qE "no encrypted values|file is not encrypted|sops metadata not found|cannot parse" "$ERRFILE"; then
    # File is not encrypted - pass through unchanged
    cat "$TMPFILE"
else
    # Real error - fail loudly
    cat "$ERRFILE" >&2
    exit 1
fi