
# Load ~/.config/environment.d in shells that didn't start from the niri session (TTY, SSH).
if [[ -z "${NIRI_SOCKET:-}" && -x /usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator ]]; then
  while IFS= read -r _kv; do case "$_kv" in PWD=*|SHLVL=*|_=*) ;; *) export "$_kv" ;; esac; done \
    < <(/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator)
  unset _kv
fi
