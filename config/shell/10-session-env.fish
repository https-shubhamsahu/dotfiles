# Load ~/.config/environment.d into shells that didn't start from the niri session (TTY, SSH).
set -l gen /usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator
if not set -q NIRI_SOCKET; and test -x $gen
    for line in ($gen)
        set -l kv (string split -m 1 = -- $line)
        contains -- $kv[1] PWD SHLVL _; and continue
        set -gx $kv[1] $kv[2]
    end
end
