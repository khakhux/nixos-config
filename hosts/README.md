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

## Flake platform selection

`flake.nix` enables `nixos-wsl.nixosModules.default` only for hosts declared
with `isWsl = true` (`currolaptop`). Native hosts omit the WSL module.
