Iniciando nixosoip...
wsl: Failed to start the systemd user session for 'nixos'. See journalctl for more details.
Welcome to your new NixOS-WSL system!

Aug 04 04:33:34 nixos systemd[1]: Created slice Slice /user/1000.
Aug 04 04:33:34 nixos systemd[1]: Starting User Runtime Directory /run/user/1000...
Aug 04 04:33:34 nixos systemd-logind[300]: New session 'c1' of user 'nixos' with class 'user' and type 'tty'.
Aug 04 04:33:34 nixos systemd[1]: Finished User Runtime Directory /run/user/1000.
Aug 04 04:33:34 nixos systemd[1]: user@1000.service: Failed to spawn executor: Device or resource busy
Aug 04 04:33:34 nixos systemd[1]: user@1000.service: Failed to spawn 'start' task: Device or resource busy
Aug 04 04:33:34 nixos systemd[1]: user@1000.service: Failed with result 'resources'.
Aug 04 04:33:34 nixos systemd[1]: Failed to start User Manager for UID 1000.
Aug 04 04:33:34 nixos systemd[1]: Started Session c1 of User nixos.
Aug 04 04:33:34 nixos shell-wrapper[330]: SIGCHLD is ignored, skipping setting environment
Aug 04 04:33:34 nixos unknown: WSL (2 - Interop) ERROR: operator():2755: systemctl is-active user@1000.service returned: failed
