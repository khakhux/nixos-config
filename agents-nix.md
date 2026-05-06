# AGENTS.md creation and update guidelines for repo

**Session ID:** ses_26f7f2dc9ffe1U6eLUFKF41s2J
**Created:** 4/15/2026, 11:37:34 AM
**Updated:** 4/15/2026, 11:40:49 AM

---

## User

Create or update `AGENTS.md` for this repository.

The goal is a compact instruction file that helps future OpenCode sessions avoid mistakes and ramp up quickly. Every line should answer: "Would an agent likely miss this without help?" If not, leave it out.

User-provided focus or constraints (honor these):


## How to investigate

Read the highest-value sources first:
- `README*`, root manifests, workspace config, lockfiles
- build, test, lint, formatter, typecheck, and codegen config
- CI workflows and pre-commit / task runner config
- existing instruction files (`AGENTS.md`, `CLAUDE.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`)
- repo-local OpenCode config such as `opencode.json`

If architecture is still unclear after reading config and docs, inspect a small number of representative code files to find the real entrypoints, package boundaries, and execution flow. Prefer reading the files that explain how the system is wired together over random leaf files.

Prefer executable sources of truth over prose. If docs conflict with config or scripts, trust the executable source and only keep what you can verify.

## What to extract

Look for the highest-signal facts for an agent working in this repo:
- exact developer commands, especially non-obvious ones
- how to run a single test, a single package, or a focused verification step
- required command order when it matters, such as `lint -> typecheck -> test`
- monorepo or multi-package boundaries, ownership of major directories, and the real app/library entrypoints
- framework or toolchain quirks: generated code, migrations, codegen, build artifacts, special env loading, dev servers, infra deploy flow
- repo-specific style or workflow conventions that differ from defaults
- testing quirks: fixtures, integration test prerequisites, snapshot workflows, required services, flaky or expensive suites
- important constraints from existing instruction files worth preserving

Good `AGENTS.md` content is usually hard-earned context that took reading multiple files to infer.

## Questions

Only ask the user questions if the repo cannot answer something important. Use the `question` tool for one short batch at most.

Good questions:
- undocumented team conventions
- branch / PR / release expectations
- missing setup or test prerequisites that are known but not written down

Do not ask about anything the repo already makes clear.

## Writing rules

Include only high-signal, repo-specific guidance such as:
- exact commands and shortcuts the agent would otherwise guess wrong
- architecture notes that are not obvious from filenames
- conventions that differ from language or framework defaults
- setup requirements, environment quirks, and operational gotchas
- references to existing instruction sources that matter

Exclude:
- generic software advice
- long tutorials or exhaustive file trees
- obvious language conventions
- speculative claims or anything you could not verify
- content better stored in another file referenced via `opencode.json` `instructions`

When in doubt, omit.

Prefer short sections and bullets. If the repo is simple, keep the file simple. If the repo is large, summarize the few structural facts that actually change how an agent should work.

If `AGENTS.md` already exists at `/home/cacu/workspaces/nixos-config`, improve it in place rather than rewriting blindly. Preserve verified useful guidance, delete fluff or stale claims, and reconcile it with the current codebase.

---

## Assistant (Build · Claude Sonnet 4.6 · 149.3s)

I'll investigate the repository structure first, then create a well-targeted `AGENTS.md`.

**Tool: task**

**Input:**
```json
{
  "description": "Investigate repo structure",
  "subagent_type": "explore",
  "prompt": "Explore the repository at /home/cacu/workspaces/nixos-config thoroughly. I need you to read and summarize the highest-signal content from:\n\n1. README files at the root\n2. Root-level config files (flake.nix, flake.lock, any .nix files at root)\n3. Directory structure (top-level directories and their purpose)\n4. Any existing instruction files: AGENTS.md, CLAUDE.md, .cursor/rules/, .cursorrules, opencode.json, .github/copilot-instructions.md\n5. CI workflows (.github/workflows/)\n6. Any task runner config (Makefile, justfile, taskfile, etc.)\n7. Key .nix files that show how the system is organized\n\nFor each source, extract:\n- What commands are used to build, test, check, apply, or deploy\n- The package/host/module structure (monorepo boundaries, host configs, home-manager, etc.)\n- Non-obvious conventions or gotchas\n- How modules/packages are wired together\n\nBe thorough. Read actual file contents, not just file names. Return a detailed summary of everything you find."
}
```

**Output:**
```
task_id: ses_26f7f1005ffe2ZuzcaHQ8vHAyP (for resuming to continue this task if needed)

<task_result>
I now have a comprehensive picture of the entire repository. Here is the full detailed summary:

---

# NixOS Config Repository — Comprehensive Summary

## Repository Identity

- **Description**: "NixOS from Scratch" — a personal NixOS configuration managed as a Nix flake.
- **Owner**: User `cacu` (Carlos), git identity `sgen0291 / crparedes@igae.hacienda.gob.es` (Spanish government employee, IGAE/Hacienda).
- **Currently active host**: `currolaptop` (WSL2 on Windows). Two other hosts (`server-docker-01`, `mininas`) are declared in `flake.nix` but have **no on-disk host directories** — they are phantom entries, likely left from prior or planned work.
- **Nix channel**: `nixos-25.05` stable + `nixpkgs-unstable` overlay for select packages.

---

## Directory Structure

```
nixos-config/
├── flake.nix                   # Root flake: inputs, mkHost factory, nixosConfigurations
├── flake.lock                  # Auto-generated lock file (all inputs pinned)
├── .gitignore / .ignore        # Ignores: result, result-*, .direnv/
├── README.md                   # Usage guide, install steps, opencode update workflow
├── instructions.md             # Extended learning/reference notes (not agent rules)
├── session-ses_27fa.md         # OpenCode AI session export (not a config file)
│
├── scripts/
│   └── update-opencode.sh      # Helper: updates nixpkgs-unstable & optionally rebuilds
│
├── hosts/
│   └── currolaptop/            # The ONLY live host (WSL2 laptop)
│       ├── configuration.nix   # System config: imports modules-dev + wsl, adds packages
│       ├── home.nix            # Home-manager: imports modules-dev/home + nvim module
│       └── user.nix            # Pure data file: mainUser, hostname, gitUser, gitEmail
│
├── modules/                    # Reusable NixOS modules (generic/server-oriented)
│   ├── common-configuration.nix  # Shared server base: boot, locale, SSH keys, packages
│   ├── common-home.nix           # Shared home-manager base: bash aliases, nrs() func
│   ├── hardened-ssh.nix          # OpenSSH with strict security defaults
│   ├── docker.nix                # Docker + docker-compose enablement
│   ├── git.nix                   # System-level git config (reads from users.nix)
│   ├── wsl.nix                   # WSL2 integration shim (wsl.enable, defaultUser)
│   ├── static-network.nix        # Parameterized static IP networking module
│   ├── proxmox-guest.nix         # QEMU guest agent for Proxmox VMs
│   ├── desktop-configuration.nix # Desktop base: sound, nil LSP, nixpkgs-fmt, vscode
│   ├── desktop-plasma.nix        # KDE Plasma 5 + SDDM + optional XRDP
│   ├── desktop-qtile.nix         # Qtile WM + ly display manager + picom + alacritty
│   └── nvim/
│       ├── neovim.nix            # Neovim home-manager module (plugins, LSP, packages)
│       └── init.lua              # Neovim Lua config (shipped as home.file)
│
├── modules-dev/                # Work-specific modules (corporate dev environment)
│   ├── configuration.nix       # WSL system config: Docker, corp CA cert, dev packages
│   ├── home.nix                # Home-manager: git, direnv, SOPS, corp CA, maven repo
│   └── cacerts/
│       └── CARaiz.pem          # Corporate root CA certificate (IGAE/MINHAC Spain)
│
└── dev-envs/
    └── java21/
        ├── flake.nix           # Dev shell: pinned JDK 21.0.2 + Maven 3.8.6 + IntelliJ
        └── flake-caraiz.nix    # Same but with corporate CA baked into the JDK cacerts
```

---

## Flake Inputs (`flake.nix`)

| Input | URL | Purpose |
|---|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-25.05` | Stable channel (primary) |
| `nixpkgs-unstable` | `github:NixOS/nixpkgs/nixpkgs-unstable` | Unstable overlay for bleeding-edge packages |
| `home-manager` | `github:nix-community/home-manager/release-25.05` | Follows stable nixpkgs |
| `nixos-wsl` | `github:nix-community/NixOS-WSL/main` | WSL2 NixOS integration |

**No** sops-nix, agenix, disko, flake-utils, nix-darwin, or other commonly seen inputs. SOPS tooling is installed as a package (`sops`, `age`) but sops-nix the flake module is not used.

---

## Host Construction Pattern (`mkHost` factory)

```nix
mkHost = hostName:
  let
    users = import ./hosts/${hostName}/user.nix;   # Pure attrset: mainUser, hostname, gitUser, gitEmail
    pkgsUnstable = import inputs.nixpkgs-unstable { ... config.allowUnfree = true; };
  in nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";          # Hardcoded — all hosts are x86_64
    specialArgs = { inherit pkgsUnstable; };  # Passed into all modules
    modules = [
      ./hosts/${hostName}/configuration.nix
      home-manager.nixosModules.home-manager
      { home-manager.users.${users.mainUser} = import ./hosts/${hostName}/home.nix;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup"; }
      nixos-wsl.nixosModules.default   # Always loaded even for non-WSL hosts (gotcha!)
    ];
  };
```

**Key gotchas:**
- `pkgsUnstable` is exposed as a `specialArgs` argument — host configs can receive it via function signature (`{ pkgsUnstable, ... }`).
- `user.nix` is a **plain Nix attrset file** (not a module), imported twice: once in `mkHost` to get `mainUser`, and again inside `configuration.nix`/`home.nix` via `envFilePath` parameter passing.
- `nixos-wsl.nixosModules.default` is unconditionally loaded in **all** hosts, which is only appropriate when all hosts are WSL. Non-WSL hosts would need to be added differently or `wsl.enable = false` must be set explicitly.
- There is no `hardware-configuration.nix` for `currolaptop` — WSL doesn't need one.

---

## Module Wiring for `currolaptop`

### System (`configuration.nix`):
```
hosts/currolaptop/configuration.nix
  └─ imports:
      ├─ modules-dev/configuration.nix { envFilePath = ./user.nix }
      │    └─ imports: modules/docker.nix
      │    └─ sets: wsl.enable, networking, locale, user, Docker, corp CA, dev packages
      │    └─ creates: /docker_data/ with docker-compose-base.yml (activation script)
      └─ modules/wsl.nix { mainUser = "cacu" }
           └─ sets: wsl.enable = true, wsl.defaultUser = "cacu"
  └─ environment.systemPackages: vscode, IntelliJ IDEA Ultimate, gocatcli, clipse,
       python314, pkgsUnstable.opencode, ripgrep, nil, nixpkgs-fmt, firefox
  └─ systemd.tmpfiles: symlink /workspaces → ~/workspaces
  └─ systemd.user.services.clipse-listener (clipboard manager daemon)
```

### Home-manager (`home.nix`):
```
hosts/currolaptop/home.nix
  └─ imports:
      ├─ modules-dev/home.nix { envFilePath = ./user.nix }
      │    └─ sets: git config (username from user.nix), direnv + nix-direnv
      │    └─ fetches: private GitLab repo "metodologia" at pinned rev
      │    │    └─ deploys: ~/.m2/settings.xml, maven formatter, git configs,
      │    │                 git attributes/ignore, SOPS config + scripts
      │    └─ builds: custom ca-bundle.crt (system CA + corp CA) at ~/.config/nixos-cacerts/ca-bundle.crt
      │    └─ activation: auto-generates age key if not present (~/.config/sops/age/keys.txt)
      │    └─ bash aliases: hello, idea-java21; function: nrs()
      │    └─ env vars: SOPS_AGE_KEY_FILE, SOPS_CONFIG
      └─ modules/nvim/neovim.nix
           └─ plugins: nvim-lspconfig, nvim-tree, telescope, neogit, gitsigns
           └─ extraPackages: nixd, nixfmt-rfc-style, ripgrep, fd
           └─ home.file ".config/nvim/init.lua" ← ./modules/nvim/init.lua
  └─ home.packages: mc (Midnight Commander)
```

---

## Commands Summary

### Building / Applying

| Command | Purpose |
|---|---|
| `sudo nixos-rebuild switch --flake /path/to/nixos-config#currolaptop` | Full system rebuild and switch |
| `nrs` (bash function in `common-home.nix` and `modules-dev/home.nix`) | Shorthand: `sudo nixos-rebuild switch --flake ~/workspaces/nixos-config#$(hostname)` |
| `sudo nixos-rebuild switch --flake ... --option ssl-cert-file /etc/ssl/proxy-certs/CARaiz.pem` | Initial bootstrap when behind corporate proxy with custom CA |
| `sudo nixos-install --flake /mnt/etc/nixos#hostname` | Fresh install from live ISO |

### Updating Packages

| Command | Purpose |
|---|---|
| `./scripts/update-opencode.sh` | Check opencode version change after updating `nixpkgs-unstable` lock |
| `./scripts/update-opencode.sh --rebuild` | Update lock + immediately rebuild for `currolaptop` |
| `./scripts/update-opencode.sh --host mininas --rebuild` | Same but for a different host |
| `nix flake lock --update-input nixpkgs-unstable` | What the script calls internally |
| `nix eval --raw '.#nixosConfigurations.currolaptop.config._module.args.pkgsUnstable.opencode.version'` | Read opencode version from evaluation |

### Dev Shells

| Command | Purpose |
|---|---|
| `cd dev-envs/java21 && nix develop` | Enter Java 21 + Maven 3.8.6 + IntelliJ dev shell |
| `idea-java21` (bash alias) | Shorthand cd + nix develop --command idea |
| `nix develop --command idea` | Launch IntelliJ IDEA inside the dev shell |

### OpenCode (AI tool)

| Command | Purpose |
|---|---|
| `opencodeweb` (bash alias in `common-home.nix`) | `opencode web --hostname 0.0.0.0 --port 4096` |

### Nix Utility Commands

| Command | Purpose |
|---|---|
| `nix-prefetch-git -- $url --rev $rev` | Get sha256 for fetchgit (used to pin the metodologia repo) |
| `nixos-generate-config --root /mnt` | Generate initial hardware config from live ISO |

---

## Non-Obvious Conventions and Gotchas

1. **`user.nix` is a pure data attrset, not a NixOS module.** It is `import`-ed directly (`= import ./user.nix`) to extract `mainUser`, `hostname`, `gitUser`, `gitEmail`. It is passed as `envFilePath` into `modules-dev/` files which then do their own `import envFilePath`. This means the same attrset is imported multiple times via different paths.

2. **The `modules-dev/` directory is the actual active configuration for `currolaptop`**; the `modules/` directory contains generic/server-oriented modules that are **not currently used** by any active host (except `docker.nix` which is imported by `modules-dev/configuration.nix`, and `wsl.nix` which is imported by `currolaptop/configuration.nix`). The files `common-configuration.nix`, `common-home.nix`, `hardened-ssh.nix`, `git.nix`, `static-network.nix`, `proxmox-guest.nix`, `desktop-*.nix` appear to be templates/library modules, not wired to any host.

3. **`flake.nix` lists `server-docker-01` and `mininas` as `nixosConfigurations`, but those host directories do not exist on disk.** Evaluating or building those would fail. They are likely planned/future hosts or leftover entries.

4. **`nixos-wsl.nixosModules.default` is loaded for ALL hosts unconditionally.** This is only correct for WSL hosts. Adding a bare-metal host would require either restructuring `mkHost` or setting `wsl.enable = false` in that host's config.

5. **`system` is hardcoded to `x86_64-linux`** in `mkHost`. No aarch64 or other arch support.

6. **Corporate CA cert (`CARaiz.pem`)** is embedded in the repo at `modules-dev/cacerts/`. It is:
   - Added to the system PKI store via `security.pki.certificateFiles` in `modules-dev/configuration.nix`.
   - Merged into a custom ca-bundle in home-manager and configured as `http.sslCAInfo` for git.
   - Baked into the JDK cacerts keystore via `flake-caraiz.nix` for Java Maven builds.
   - Used during initial `nixos-rebuild switch` via `--option ssl-cert-file`.

7. **Private GitLab repo is fetched at build time.** `modules-dev/home.nix` uses `pkgs.fetchgit` with a pinned SHA to fetch a private internal repository (`metodologia`) from `gitlab.central.sepg.minhac.age`. This requires SSH access to that GitLab at build time. The fetched content deploys Maven settings, git config, git attributes, SOPS scripts, and a Maven formatter config.

8. **Age key is auto-generated on first home-manager activation** via a `home.activation` script. The public key must then be manually added to the relevant `.sops.yaml` files in other repositories.

9. **`opencode` is installed from `pkgsUnstable`** (not stable), specifically via `pkgsUnstable.opencode` in the host's `configuration.nix`. The `update-opencode.sh` script exists precisely to track version bumps in the unstable channel without updating everything else.

10. **`home-manager.backupFileExtension = "backup"`** is set — if home-manager wants to create a file that already exists unmanaged, it will rename the existing file to `<file>.backup` rather than failing.

11. **`clipse` (clipboard manager) runs as a systemd user service** (`clipse-listener`), started at user login via `default.target`. It restarts on failure with a 5-second delay.

12. **`/workspaces` is a symlink** created by `systemd.tmpfiles.rules` pointing to `~/workspaces`. This is a WSL2 convention to match the VS Code Remote `devcontainers` standard path.

13. **`nix-ld` is enabled** in both `modules-dev/configuration.nix` and `modules/common-configuration.nix` to allow VS Code Remote SSH to run dynamically linked binaries.

14. **No CI workflows.** There is no `.github/` directory. No GitHub Actions, no automated checks, no automated builds.

15. **No task runner.** There is no `Makefile`, `justfile`, or `Taskfile`. The only automation is `scripts/update-opencode.sh`.

16. **No AGENTS.md, CLAUDE.md, opencode.json, or .cursor rules files.** The `session-ses_27fa.md` is an exported OpenCode chat session (from April 12, 2026) about how OpenCode rules files work — it is not itself a rules file. The `instructions.md` is a personal learning notebook, not agent instructions.

---

## Dev Environment: `dev-envs/java21/`

Two variants exist:
- **`flake.nix`**: Standard — JDK 21.0.2 (pinned from nixos-24.05), Maven 3.8.6 (pinned from nixos-22.11, overridden to use pinned JDK), IntelliJ from unstable. JDK and Maven are symlinked to stable paths (`~/.jdks/java21-pinned`, `~/.m2/maven-pinned`) so IntelliJ config doesn't break across rebuilds.
- **`flake-caraiz.nix`**: Corporate variant — same tools, but JDK is post-processed with `pkgs.runCommand` to `keytool -importcert` the corporate CA (`CARaiz.pem`) into the JDK's own `cacerts` keystore. Uses `idea-ultimate` (licensed) instead of community. This is the version to use at work.

The dev shells use multiple pinned nixpkgs channels simultaneously (22.11, 24.05, 25.05, unstable) to get exactly the right package versions, demonstrating Nix's ability to pin individual packages to different channel snapshots.

---

## Module Inventory (Quick Reference)

| Module | Used By | Purpose |
|---|---|---|
| `modules-dev/configuration.nix` | `currolaptop` | Primary WSL system config |
| `modules-dev/home.nix` | `currolaptop` | Primary home-manager config |
| `modules/wsl.nix` | `currolaptop` | WSL2 shim |
| `modules/docker.nix` | `modules-dev/configuration.nix` | Docker enablement |
| `modules/nvim/neovim.nix` | `currolaptop/home.nix` | Neovim setup |
| `modules/common-configuration.nix` | Unused (template) | Server base with static IP |
| `modules/common-home.nix` | Unused (template) | Home base with `nrs()` |
| `modules/hardened-ssh.nix` | Unused (template) | Hardened OpenSSH |
| `modules/git.nix` | Unused (reads `users.nix` that doesn't exist at root) | System git config |
| `modules/static-network.nix` | Unused (template) | Parameterized static IP |
| `modules/proxmox-guest.nix` | Unused (template) | QEMU agent for Proxmox |
| `modules/desktop-configuration.nix` | Unused (template) | Desktop base |
| `modules/desktop-plasma.nix` | Unused (template/broken) | KDE Plasma 5 |
| `modules/desktop-qtile.nix` | Unused (template) | Qtile WM |

**Note**: `modules/git.nix` and `modules/common-configuration.nix` reference `../users.nix` which does not exist at the root level of the repo. They would fail to evaluate if imported.
</task_result>
```

---

## Assistant (Build · Claude Sonnet 4.6 · 3.0s)

Now I have a thorough picture of the repo. Let me check if there's an existing `AGENTS.md`:

**Tool: glob**

**Input:**
```json
{
  "pattern": "AGENTS.md",
  "path": "/home/cacu/workspaces/nixos-config"
}
```

**Output:**
```
No files found
```

---

## Assistant (Build · Claude Sonnet 4.6 · 32.8s)

No existing file. I'll write a focused `AGENTS.md` now:

**Tool: write**

**Input:**
```json
{
  "filePath": "/home/cacu/workspaces/nixos-config/AGENTS.md",
  "content": "# AGENTS.md — NixOS Config\n\nPersonal NixOS flake for a single active host (`currolaptop`, WSL2 on Windows). The `modules/` tree is mostly library/template code; the live configuration lives in `modules-dev/` and `hosts/currolaptop/`.\n\n## Apply the config\n\n```bash\n# Short alias (defined in modules-dev/home.nix and modules/common-home.nix):\nnrs\n# Expands to:\nsudo nixos-rebuild switch --flake ~/workspaces/nixos-config#$(hostname)\n\n# Full form (if alias unavailable):\nsudo nixos-rebuild switch --flake /path/to/nixos-config#currolaptop\n\n# Behind corporate proxy (first bootstrap only):\nsudo nixos-rebuild switch --flake ... --option ssl-cert-file /etc/ssl/proxy-certs/CARaiz.pem\n```\n\nThere is no CI, no Makefile, no linter, and no test suite. The only verification is a successful `nixos-rebuild switch`.\n\n## Update opencode (unstable input)\n\n```bash\n./scripts/update-opencode.sh            # checks version bump in nixpkgs-unstable\n./scripts/update-opencode.sh --rebuild  # also rebuilds currolaptop immediately\n```\n\n`opencode` is installed from `pkgsUnstable`, not stable nixpkgs. This script updates only the `nixpkgs-unstable` lock entry.\n\n## Dev shell (Java/Maven/IntelliJ)\n\n```bash\ncd dev-envs/java21 && nix develop          # standard (no corp CA)\n# or use the alias:\nidea-java21\n```\n\nUse `dev-envs/java21/flake-caraiz.nix` instead when behind the corporate proxy — it bakes `CARaiz.pem` into the JDK cacerts keystore.\n\n## Key architecture facts\n\n- **One live host**: `currolaptop`. The flake also declares `server-docker-01` and `mininas`, but their `hosts/` directories do not exist — evaluating or building them will fail.\n- **`system` is hardcoded to `x86_64-linux`** in the `mkHost` factory in `flake.nix`. All hosts share this.\n- **`nixos-wsl.nixosModules.default` is loaded unconditionally for every host** in `mkHost`. Adding a non-WSL host requires restructuring `mkHost` or explicitly setting `wsl.enable = false`.\n- **`user.nix` is a plain attrset, not a NixOS module.** It is `import`-ed directly to get `mainUser`, `hostname`, `gitUser`, `gitEmail`. It is passed as `envFilePath` into `modules-dev/` files, which re-import it themselves.\n- **`pkgsUnstable`** is threaded through `specialArgs` and available in any module that declares it in its function signature.\n- **`modules/common-configuration.nix`** and **`modules/git.nix`** reference `../users.nix` which does not exist at the repo root. Do not import these modules; they would fail to evaluate.\n\n## Directory map\n\n| Path | Role |\n|---|---|\n| `hosts/currolaptop/` | The only active host (WSL2) |\n| `hosts/currolaptop/user.nix` | Pure data: `mainUser`, `hostname`, `gitUser`, `gitEmail` |\n| `modules-dev/configuration.nix` | Active system config: Docker, corp CA, dev packages |\n| `modules-dev/home.nix` | Active home-manager config: git, direnv, SOPS, corp CA bundle |\n| `modules-dev/cacerts/CARaiz.pem` | Corporate root CA (IGAE/MINHAC Spain); do not remove |\n| `modules/` | Library/template modules — mostly unused by active hosts |\n| `modules/nvim/` | Neovim home-manager module; imported by `currolaptop/home.nix` |\n| `modules/wsl.nix` | WSL2 shim; imported by `currolaptop/configuration.nix` |\n| `modules/docker.nix` | Docker; imported by `modules-dev/configuration.nix` |\n| `dev-envs/java21/` | Dev shell: pinned JDK 21 + Maven 3.8.6 + IntelliJ |\n| `scripts/update-opencode.sh` | Only automation script |\n\n## Corporate environment notes\n\n- `modules-dev/home.nix` fetches a **private internal GitLab repo** (`metodologia`) at build time using `pkgs.fetchgit` with a pinned SHA. This requires SSH access to `gitlab.central.sepg.minhac.age` during rebuild. Update the `rev` and `sha256` in that file when the repo changes.\n- An **age key** is auto-generated on first home-manager activation (`~/.config/sops/age/keys.txt`). After generation, add the public key to `.sops.yaml` files in other repos that use SOPS encryption.\n- `home-manager.backupFileExtension = \"backup\"` is set globally — conflicting unmanaged files are renamed to `<file>.backup` rather than causing a failure.\n\n## Nix channels\n\n| Input | Pin | Used for |\n|---|---|---|\n| `nixpkgs` | `nixos-25.05` | Everything (stable) |\n| `nixpkgs-unstable` | rolling | `opencode` and select packages via `pkgsUnstable` |\n| `home-manager` | `release-25.05` | Follows stable nixpkgs |\n| `nixos-wsl` | `main` | WSL2 integration |\n"
}
```

**Output:**
```
Wrote file successfully.
```

---

## Assistant (Build · Claude Sonnet 4.6 · 9.7s)

`AGENTS.md` created at the repo root. Here's what it covers and why each section earns its place:

- **Apply the config** — the `nrs` alias and the `--option ssl-cert-file` proxy flag are non-obvious; an agent would likely guess the wrong rebuild command.
- **Update opencode** — the script is the only automation; documenting that `opencode` comes from `pkgsUnstable` (not stable) prevents incorrect update attempts.
- **Dev shell** — two flake variants exist (`flake.nix` vs `flake-caraiz.nix`); using the wrong one breaks Maven SSL in the corporate environment.
- **Key architecture facts** — the phantom hosts (`server-docker-01`, `mininas`) would cause hard-to-diagnose evaluation failures; the unconditional WSL module load is a gotcha for any new host; `user.nix`-as-data-not-module is a pattern an agent would likely misread.
- **Directory map** — clarifies which `modules/` files are unused templates vs. which are actually wired to the live host.
- **Corporate environment notes** — the private GitLab fetch at build time is invisible from filenames alone; the age key bootstrapping step has external side effects in other repos.
- **Nix channels** — the stable/unstable split matters for any package addition decision.

---

