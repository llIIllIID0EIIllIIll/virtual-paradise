# SDDM theme

`Main.qml` is the login screen, installed by `lib/sddm.sh` as its own theme:

    /usr/share/sddm/themes/virtual-paradise/
    /etc/sddm.conf.d/zz-virtual-paradise-theme.conf

`install.sh` used to copy `Main.qml` over `/usr/share/sddm/themes/omarchy/Main.qml`,
a file owned by the `omarchy-settings` package. That made the login screen a
modified copy of a system theme: package updates silently reverted it, and
`uninstall.sh` had no way to put the stock theme back. The theme now ships
complete and self-contained, and the distro theme is left alone.

The five small PNGs in `assets/` come from Omarchy's own SDDM theme
(`omarchy-settings`, MIT licensed) so the login screen looks the same without
depending on that directory at runtime.
