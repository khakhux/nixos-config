# Host inventory

These are the active machines. Check `hostname` before host-specific checks or
rebuilds; use only the matching host target.

| Host | Role | Platform |
|---|---|---|
| `currolaptop` | Java software development | NixOS under WSL2 on a Windows 11 laptop |
| `mininas` | Server hosting several services | NixOS on a mini PC |
| `minipc-n150` | Desktop | Native NixOS on a mini PC |

Other host directories and flake declarations are legacy, experimental, or
incomplete. Do not treat them as active without confirmation.

Server configurations live in `hosts/servers/`, desktop configurations in
`hosts/desktops/`, and the WSL development host in `hosts/currolaptop/`.

## Fast checks

From the repository root, check changed files (staged, unstaged, and untracked)
in active hosts and shared configuration:

```sh
nix shell --inputs-from . nixpkgs#nixfmt-rfc-style nixpkgs#shellcheck --command bash scripts/check-fast.sh
```

This parses and format-checks changed Nix files, and runs `bash -n` and
ShellCheck on changed shell scripts. It skips legacy host directories and
does not evaluate, build, or switch a host. The tools are supplied by the
Nix shell if they are not installed locally.

## Flake platform selection

`flake.nix` enables `nixos-wsl.nixosModules.default` only for hosts declared
with `isWsl = true` (`currolaptop`). Native hosts omit the WSL module.
