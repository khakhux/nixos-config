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

## Important flake caveat

`flake.nix` currently loads `nixos-wsl.nixosModules.default` unconditionally
through `mkHost`. That matches `currolaptop`, but not the native NixOS hosts.
Do not assume the flake can correctly build or apply `mininas` or
`minipc-n150` until the host factory is made platform-aware.
