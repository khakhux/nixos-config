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
TMPFILE=$(mktemp "${REPO_ROOT}/.sops-clean-XXXXXX.${FILE_EXT}")
OUTFILE=$(mktemp "${REPO_ROOT}/.sops-out-XXXXXX.${FILE_EXT}")
ERRFILE=$(mktemp /tmp/sops-err-XXXXXX.txt)
trap "rm -f '$TMPFILE' '$OUTFILE' '$ERRFILE'" EXIT

cat > "$TMPFILE"

if sops --encrypt --input-type "$EXT" --output-type "$EXT" "$TMPFILE" > "$OUTFILE" 2>"$ERRFILE"; then
    cat "$OUTFILE"
elif grep -qE "no matching creation rules" "$ERRFILE"; then
    # Legitimately nothing to encrypt - pass through unchanged
    cat "$TMPFILE"
else
    # Real error - fail loudly
    cat "$ERRFILE" >&2
    exit 1
fi
