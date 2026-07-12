# Docker Image Transfer: Harbor → Air-Gapped Machine

These two scripts let you copy Docker images that live in a private Harbor
registry (`harbor.dockersl.central.sepg.minhac.age/imagenes-igae/*`) to a
machine that has **no access to Harbor**, by exporting them to `.tar` files
and importing those tar files on the target machine.

```
[Machine A - has Harbor access]          [Machine B - no Harbor access]
        |                                          ^
        |  1. export-images.sh                     |
        v                                          |
  /workspaces/docker-images/*.tar  --(copy)-->  /workspaces/docker-images/*.tar
                                                     |
                                                     | 2. import-images.sh
                                                     v
                                              local docker images
```

## Files

- **`export-images.sh`** — run on the machine that has Harbor access (and
  the images already pulled/built locally). Saves every local image whose
  repository starts with `harbor.dockersl.central.sepg.minhac.age/imagenes-igae/`
  to a `.tar` file.
- **`import-images.sh`** — run on the target/air-gapped machine. Loads
  images from `.tar` files into the local Docker daemon, skipping images
  that already exist and warning about conflicts.

## Prerequisites

- `docker` on both machines.
- `jq` installed on the machine running `import-images.sh` (used to read
  each tar's `manifest.json` without needing to load it first).
- Some way to copy files between the two machines (USB drive, `scp`,
  internal file share, etc.) — this is outside the scope of these scripts.

## Workflow

### 1. On the machine with Harbor access

```bash
./export-images.sh
```

This scans your local `docker images` list, and for every image whose
repository starts with `harbor.dockersl.central.sepg.minhac.age/imagenes-igae/`,
runs `docker save` into:

```
/workspaces/docker-images/<repo>_<tag>_<imageid>.tar
```

Slashes in the repository name are replaced with underscores in the
filename (the tar's internal metadata still has the real repo/tag/id —
the filename is just for humans). Images that have already been exported
(same target filename already present) are skipped, so you can re-run
this script periodically to pick up newly built/pulled images only.

### 2. Copy the tar files to the target machine

Copy the contents of `/workspaces/docker-images/` from Machine A to the
same path on Machine B, using whatever transfer method is available in
your environment (USB drive, `scp`, internal file share, etc.).

### 3. On the air-gapped target machine

```bash
./import-images.sh
```

This looks at every `.tar` file in `/workspaces/docker-images` (default
path — override with `-d`) and, **without blindly loading everything**,
inspects each tar's embedded `manifest.json` to determine the image's
repository, tag, and image ID, then decides what to do:

| Situation                                                        | Action                                  |
|--------------------------------------------------------------------|------------------------------------------|
| No local image with that repo:tag                                | Load it                                   |
| Local image exists with same repo, tag **and** image ID           | Skip (already up to date)                 |
| Local image exists with same repo:tag but a **different** image ID | Warn, don't load (unless `-o` is given)  |

To force-overwrite images that have a matching repo:tag but a different
ID (e.g. you rebuilt/repushed a `latest` tag), use:

```bash
./import-images.sh -o
```

## Options

### `export-images.sh`
No options — output directory (`/workspaces/docker-images`) and the
Harbor prefix are fixed at the top of the script; edit the script if you
need to change either.

### `import-images.sh`

| Flag        | Description                                                    |
|-------------|------------------------------------------------------------------|
| `-d DIR`    | Directory to read `.tar` files from (default: `/workspaces/docker-images`) |
| `-o`        | Overwrite: load/retag images even if a same-named repo:tag already exists with a different image ID |
| `-h`        | Show help                                                       |

Examples:

```bash
# Default: import from /workspaces/docker-images, warn on conflicts
./import-images.sh

# Import from a custom directory
./import-images.sh -d /mnt/usb/docker-images

# Overwrite any repo:tag whose image ID differs from what's in the tar
./import-images.sh -o
```

## Notes / Limitations

- **Image ID format**: Docker's `manifest.json` inside a saved tar stores
  the image config either as `<hash>.json` (older Docker) or as
  `blobs/sha256/<hash>` (newer, containerd-backed Docker). Both formats
  are handled automatically — the script always compares against the
  short (12-character) image ID shown by `docker images`.
- **One image per tar**: `export-images.sh` produces one tar per image,
  which is what `import-images.sh` is designed around. If you hand-craft
  a tar containing multiple images/tags, `docker load` will load *all* of
  them together as soon as **any** one of them needs loading — it cannot
  selectively load only some of the tags inside a single tar.
- **No registry access needed on the target machine** — `import-images.sh`
  never talks to Harbor; it only reads local `.tar` files and the local
  Docker daemon.
- Re-running either script is safe: already-exported tars and
  already-present images (matching repo, tag, and ID) are skipped.