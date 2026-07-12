#!/usr/bin/env bash
#
# import-images.sh
#
# Loads docker images from every .tar file in /workspaces/docker-images
# (by default) into the local docker repository, with these rules:
#
#   - If an image with the same repo, tag AND image id already exists,
#     it is skipped (nothing to do).
#   - If an image with the same repo and tag exists but with a DIFFERENT
#     image id, a warning is shown and the tar is NOT loaded, unless
#     -o (overwrite) is given, in which case it is loaded/retagged.
#   - If no image with that repo:tag exists at all, the tar is loaded.
#
# Requires: docker, jq, tar
#
# Note: this script assumes each tar file contains a single image (as
# produced by export-images.sh). If a tar contains multiple images/tags,
# `docker load` will load all of them together as soon as at least one
# of them requires loading - it cannot selectively load only some of the
# tags contained in a single tar file.

set -euo pipefail

INPUT_DIR="/workspaces/docker-images"
OVERWRITE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [-o] [-d DIR] [-h]

  -o        Overwrite: retag images even if an image already exists with
            the same repository:tag but a different image ID.
  -d DIR    Directory containing .tar files (default: ${INPUT_DIR})
  -h        Show this help.
EOF
    exit 1
}

while getopts ":od:h" opt; do
    case "$opt" in
        o) OVERWRITE=true ;;
        d) INPUT_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed." >&2
    exit 1
fi

shopt -s nullglob
tarfiles=("${INPUT_DIR}"/*.tar)
shopt -u nullglob

if [[ ${#tarfiles[@]} -eq 0 ]]; then
    echo "No .tar files found in ${INPUT_DIR}"
    exit 0
fi

loaded_count=0
skipped_count=0
warned_count=0

for tarfile in "${tarfiles[@]}"; do
    echo "== Processing ${tarfile} =="

    manifest_json=$(tar -xOf "$tarfile" manifest.json 2>/dev/null) || {
        echo "  Warning: could not read manifest.json from ${tarfile}, skipping." >&2
        warned_count=$((warned_count + 1))
        continue
    }

    entry_count=$(echo "$manifest_json" | jq 'length')
    needs_load=false

    for ((i = 0; i < entry_count; i++)); do
        entry=$(echo "$manifest_json" | jq -c ".[$i]")
        config_file=$(echo "$entry" | jq -r '.Config')
        # Config can be either "<hash>.json" (legacy docker save format) or
        # "blobs/sha256/<hash>" (newer containerd-backed docker save format).
        full_id="${config_file##*/}"
        full_id="${full_id%.json}"
        short_id="${full_id:0:12}"

        mapfile -t repo_tags < <(echo "$entry" | jq -r '.RepoTags[]? // empty')

        if [[ ${#repo_tags[@]} -eq 0 ]]; then
            echo "  Warning: image entry ${short_id} has no RepoTags, cannot check/load it individually, skipping."
            warned_count=$((warned_count + 1))
            continue
        fi

        for repo_tag in "${repo_tags[@]}"; do
            repo="${repo_tag%:*}"
            tag="${repo_tag##*:}"

            existing_id=$(docker images -q "${repo}:${tag}" 2>/dev/null || true)

            if [[ -n "$existing_id" && "$existing_id" == "$short_id" ]]; then
                echo "  Skip: ${repo}:${tag} (${short_id}) already exists with same image id."
                skipped_count=$((skipped_count + 1))
                continue
            fi

            if [[ -n "$existing_id" && "$existing_id" != "$short_id" ]]; then
                if [[ "$OVERWRITE" == true ]]; then
                    echo "  Overwrite: ${repo}:${tag} existing id ${existing_id} -> new id ${short_id}"
                    needs_load=true
                else
                    echo "  WARNING: ${repo}:${tag} exists with a different image id (existing: ${existing_id}, tar: ${short_id}). Use -o to overwrite. Not loaded."
                    warned_count=$((warned_count + 1))
                fi
                continue
            fi

            echo "  New: ${repo}:${tag} (${short_id}) will be loaded."
            needs_load=true
        done
    done

    if [[ "$needs_load" == true ]]; then
        docker load -i "$tarfile" >/dev/null
        loaded_count=$((loaded_count + 1))
    fi
done

echo
echo "Done. Tar files loaded: ${loaded_count}, image(s) skipped (already present): ${skipped_count}, warning(s): ${warned_count}."