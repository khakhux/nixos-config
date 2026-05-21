#!/usr/bin/env bash
set -euo pipefail

EXT="$1"

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

has_plaintext_targets() {
  case "$EXT" in
    yaml)
      grep -qE "^[[:space:]]*([\"'][^\"']*_enc[\"']|[^#[:space:]][^:]*_enc)[[:space:]]*:" "$TMPFILE"
      ;;
    dotenv)
      grep -qE "^[[:space:]]*[^#;[:space:]][^=:]*_enc[[:space:]]*[:=]" "$TMPFILE"
      ;;
    *)
      grep -qE "_enc" "$TMPFILE"
      ;;
  esac
}

cat > "$TMPFILE"

if ! has_plaintext_targets 2>/dev/null; then
  cat "$TMPFILE"
  exit 0
fi

if sops --encrypt --input-type "$EXT" --output-type "$EXT" "$TMPFILE" > "$OUTFILE" 2>"$ERRFILE"; then
  cat "$OUTFILE"
elif grep -qE "no matching creation rules" "$ERRFILE"; then
  cat "$TMPFILE"
else
  cat "$ERRFILE" >&2
  exit 1
fi