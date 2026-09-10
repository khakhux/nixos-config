# Updating your system regularly

The key thing to understand is that **`nix flake update` updates your inputs, not your installed system**.

Think of it as two steps:

```text
nix flake update
       ↓
flake.lock gets newer versions
       ↓
nixos-rebuild switch --flake .
       ↓
your running system changes
```

So a normal manual update is:

```bash
cd ~/workspaces/nixos-config

nix flake update
sudo nixos-rebuild switch --flake .
```

I'd actually recommend doing it in two stages:

```bash
nix flake update
```

then:

```bash
sudo nixos-rebuild test --flake .
```

If everything works:

```bash
sudo nixos-rebuild switch --flake .
```

`test` activates the configuration without making it the default boot configuration, which is useful for catching problems.

---

## But don't necessarily run `nix flake update` every day

With your setup, you have:

```text
nixpkgs 25.05
nixpkgs-unstable
home-manager 25.05
NixOS-WSL 25.05
```

Updating **all** of those simultaneously can introduce several unrelated changes.

I'd recommend:

### Weekly/monthly

```bash
nix flake update
sudo nixos-rebuild test --flake .
```

Then switch if successful.

### When you specifically want newer Codex

You don't need to update everything. You can update just:

```bash
nix flake lock --update-input nixpkgs-unstable
```

Then:

```bash
sudo nixos-rebuild switch --flake .
```

This is particularly useful for your `pkgsUnstable.codex`.

---

# One thing I'd change in your current setup

You're currently on **NixOS 25.05**.

That release is quite old now. Rather than trying to make 25.05 receive indefinite updates, I'd plan a **major NixOS release upgrade**.

For example, eventually:

```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
```

and corresponding compatible branches for:

```nix
home-manager
nixos-wsl
```

The important principle is:

> **Use the stable NixOS release as your base, and unstable selectively for packages that need it.**

That's much safer than making the entire OS unstable just to get things like Codex.

---

## An update workflow I'd recommend for you

For your current configuration:

```bash
# 1. Update all flake inputs
nix flake update

# 2. Check what changed
git diff flake.lock

# 3. Build without activating
nix build .#nixosConfigurations.currolaptop.config.system.build.toplevel

# 4. Test the configuration
sudo nixos-rebuild test --flake .

# 5. If everything looks good
sudo nixos-rebuild switch --flake .
```

If you use Git for your NixOS configuration, this is especially nice:

```bash
git diff flake.lock
git diff
```

before switching.

---
