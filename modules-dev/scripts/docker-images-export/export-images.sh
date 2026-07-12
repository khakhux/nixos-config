#!/usr/bin/env bash
#
# export-images.sh
#
# Exports every local docker image whose repository starts with:
#   harbor.dockersl.central.sepg.minhac.age/imagenes-igae/
# to a tar file in /workspaces/docker-images.
#
# Output filename format: <repo>_<tag>_<imageid>.tar
# (slashes in the repository name are replaced with underscores)

set -euo pipefail

OUTPUT_DIR="/workspaces/docker-images"
PREFIX="harbor.dockersl.central.sepg.minhac.age/imagenes-igae/"

mkdir -p "$OUTPUT_DIR"

echo "Exporting docker images with repository prefix: ${PREFIX}"
echo "Output directory: ${OUTPUT_DIR}"
echo

count=0
skipped=0

while IFS=$'\t' read -r repo tag id; do
    # Skip dangling / untagged images - can't be referenced by name
    if [[ "$repo" == "<none>" || "$tag" == "<none>" ]]; then
        continue
    fi

    # Only process images matching the desired prefix
    if [[ "$repo" != ${PREFIX}* ]]; then
        continue
    fi

    # Sanitize repo/tag for use in a filename (replace / with _)
    safe_repo="${repo//\//_}"
    safe_tag="${tag//\//_}"

    filename="${safe_repo}_${safe_tag}_${id}.tar"
    filepath="${OUTPUT_DIR}/${filename}"

    if [[ -f "$filepath" ]]; then
        echo "Already exists, skipping: ${filepath}"
        skipped=$((skipped + 1))
        continue
    fi

    echo "Saving ${repo}:${tag} (${id}) -> ${filepath}"
    docker save -o "$filepath" "${repo}:${tag}"

    count=$((count + 1))
done < <(docker images --format '{{.Repository}}	{{.Tag}}	{{.ID}}')

echo
echo "Done. ${count} image(s) exported, ${skipped} skipped (already existed)."