#!/usr/bin/env bash
set -euo pipefail

EXT="$1"
GIT_PATH="${2:-}"

case "$EXT" in
  yaml) FILE_EXT="yaml" ;;
  dotenv) FILE_EXT="properties" ;;
  *) FILE_EXT="$EXT" ;;
esac

REPO_ROOT=$(git rev-parse --show-toplevel)
TMPFILE=$(mktemp "${REPO_ROOT}/.sops-clean-XXXXXX.${FILE_EXT}")
OUTFILE=$(mktemp "${REPO_ROOT}/.sops-out-XXXXXX.${FILE_EXT}")
DECRYPTEDFILE=$(mktemp "${REPO_ROOT}/.sops-decrypted-XXXXXX.${FILE_EXT}")
ERRFILE=$(mktemp /tmp/sops-err-XXXXXX.txt)
trap "rm -f '$TMPFILE' '$OUTFILE' '$DECRYPTEDFILE' '$ERRFILE'" EXIT

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

same_content_ignoring_final_newline() {
  local left="$1"
  local right="$2"
  local left_size right_size last_byte

  cmp -s "$left" "$right" && return 0

  left_size=$(wc -c < "$left")
  right_size=$(wc -c < "$right")

  if (( left_size == right_size + 1 )); then
    last_byte=$(tail -c 1 "$left" | od -An -t x1 | tr -d '[:space:]')
    [[ "$last_byte" == "0a" ]] && cmp -n "$right_size" "$left" "$right"
  elif (( right_size == left_size + 1 )); then
    last_byte=$(tail -c 1 "$right" | od -An -t x1 | tr -d '[:space:]')
    [[ "$last_byte" == "0a" ]] && cmp -n "$left_size" "$left" "$right"
  else
    return 1
  fi
}

cat > "$TMPFILE"

if ! has_plaintext_targets 2>/dev/null; then
  cat "$TMPFILE"
  exit 0
fi

# Reuse the staged blob when its contents match (allowing a missing final LF).
if [[ -n "$GIT_PATH" ]] &&
    git -C "$REPO_ROOT" cat-file blob ":$GIT_PATH" > "$OUTFILE" 2>/dev/null &&
    { same_content_ignoring_final_newline "$TMPFILE" "$OUTFILE" ||
        { sops --decrypt --input-type "$EXT" --output-type "$EXT" "$OUTFILE" > "$DECRYPTEDFILE" 2>/dev/null &&
            same_content_ignoring_final_newline "$TMPFILE" "$DECRYPTEDFILE"; }; }; then
    cat "$OUTFILE"
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
