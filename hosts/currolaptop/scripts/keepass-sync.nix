{ pkgs }:

pkgs.writeShellScriptBin "keepass-sync"''
    echo "syncing keepass dbs" | ${pkgs.cowsay}/bin/cowsay | ${pkgs.lolcat}/bin/lolcat
    scp $HOME/users/igae2.kdbx mininas-syncs:/backups/curro/users
    scp $HOME/users/.AdminDigital.kdbx mininas-syncs:/backups/curro/users
    scp mininas-syncs:/backups/pixel10a/Download/user/Credentials.kdbx $HOME/users/
''