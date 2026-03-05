# SOPS Setup for Encrypted Git Repositories

This directory contains the configuration for automatic encryption and decryption of sensitive files in git repositories using SOPS (Secrets OPerationS) and age encryption.

## Files Created

- **`.sops.yaml`**: SOPS configuration defining which files should be encrypted and with which keys
- **`.gitattributes`**: Git attributes file specifying which file types use SOPS filters
- **`firma-git-config`**: Git filter configuration for SOPS clean/smudge operations
- **`test-sops.sh`**: Test script to verify SOPS setup is working correctly

## How It Works

1. **Age Key Generation**: On first `home-manager switch`, an age encryption key pair is generated at `~/.config/sops/age/keys.txt`

2. **Git Filter Setup**: Git is configured to automatically:
   - **Encrypt** files when committing (clean filter)
   - **Decrypt** files when checking out (smudge filter)

3. **File Type Detection**: Based on `.gitattributes`, these file types are automatically encrypted:
   - `*.properties`
   - `*.yaml`
   - `*.yml`

## Installation

The SOPS setup is integrated into the NixOS configuration:

### Packages Installed (configuration.nix)
- `sops` - Secrets encryption tool
- `age` - Modern encryption tool

### Home Manager Configuration (home.nix)
- Age key generation on first run
- Git configuration with SOPS filters
- SOPS configuration files deployment
- `SOPS_AGE_KEY_FILE` environment variable

## Usage

### First Time Setup

1. Apply the configuration:
   ```bash
   sudo nixos-rebuild switch --flake ~/workspaces/nixos-config#$(hostname)
   home-manager switch --flake ~/workspaces/nixos-config#$(hostname)
   ```

2. Note your age public key (displayed during first run or get it with):
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   ```

3. Update `.sops.yaml` in your project repositories with your public key:
   ```yaml
   creation_rules:
     - path_regex: \.properties$
       age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

### Testing the Setup

Run the test script to verify everything is working:
```bash
/workspaces/nixos-config/modules-dev/test-sops.sh
```

The test will:
- Check if sops and age are installed
- Verify age key exists
- Create a test git repository
- Encrypt a properties file on commit
- Verify the file is encrypted in git but decrypted in working directory
- Test git diff shows decrypted content

### Using in Your Repositories

1. Copy `.sops.yaml` to your repository root and update it with your age public key
2. Ensure `.gitattributes` is in your repository (or use the global one at `~/.gitattributes`)
3. Create/edit sensitive files (`.properties`, `.yaml`, `.yml`)
4. Add and commit - files will be automatically encrypted
5. Files remain decrypted in your working directory for normal editing

### Manual Encryption/Decryption

Encrypt a file manually:
```bash
sops --encrypt myfile.properties > myfile.properties.enc
```

Decrypt a file manually:
```bash
sops --decrypt myfile.properties.enc > myfile.properties
```

Edit an encrypted file in place:
```bash
sops myfile.properties
```

## Configuration Files

### .sops.yaml
Defines encryption rules. Update the age public key with your actual key:
```yaml
creation_rules:
  - path_regex: \.properties$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - path_regex: \.ya?ml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### .gitattributes
Specifies which files use SOPS filters:
```
*.properties filter=sops diff=sops
*.yaml       filter=sops diff=sops
*.yml        filter=sops diff=sops
```

### firma-git-config
Git filter configuration:
```ini
[filter "sops"]
    clean    = sops --encrypt /dev/stdin
    smudge   = sops --decrypt /dev/stdin
    required = true

[diff "sops"]
    textconv = sops --decrypt
```

## Environment Variables

- `SOPS_AGE_KEY_FILE`: Points to `~/.config/sops/age/keys.txt` (set automatically)

## Migration to metodologiaRepo

Currently, the SOPS configuration files are stored locally in this repository. To migrate to fetching from metodologiaRepo:

1. Add the files to the metodologia repository:
   - `firma-git-config`
   - `.gitattributes`
   - `.sops.yaml`

2. Uncomment the lines in `home.nix`:
   ```nix
   # home.file.".config/git/sops-config".source = "${metodologiaRepo}/firma-git-config";
   # home.file.".gitattributes".source = "${metodologiaRepo}/.gitattributes";
   # home.file."/workspaces/.sops.yaml".source = "${metodologiaRepo}/.sops.yaml";
   ```

3. Comment out or remove the local file sources

## Troubleshooting

### Files not being encrypted
- Check that `.sops.yaml` exists in repository root
- Verify your age public key is in `.sops.yaml`
- Check that `.gitattributes` is properly configured
- Ensure `SOPS_AGE_KEY_FILE` environment variable is set

### "no age key found" error
- Verify age key exists: `ls -la ~/.config/sops/age/keys.txt`
- Check environment variable: `echo $SOPS_AGE_KEY_FILE`
- Re-run home-manager switch to generate key

### Git filters not working
- Check git configuration: `git config --get-all include.path`
- Verify filter is defined: `git config --get filter.sops.clean`
- Check core.attributesFile: `git config --get core.attributesFile`

### "failed to decrypt" error
- Ensure you have the correct age private key
- Verify the file was encrypted with your public key
- Check SOPS_AGE_KEY_FILE points to the correct key file

## Security Notes

- **Never commit** `~/.config/sops/age/keys.txt` to git
- Back up your age private key securely (outside of git)
- Each team member needs their own age key pair
- Add all team members' public keys to `.sops.yaml` for shared repositories
- The age private key is required to decrypt files - keep it safe!

## References

- [SOPS Documentation](https://github.com/getsops/sops)
- [age Encryption](https://github.com/FiloSottile/age)
- [Git Filters Documentation](https://git-scm.com/docs/gitattributes#_filter)
