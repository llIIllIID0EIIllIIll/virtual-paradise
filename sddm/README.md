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
depending on that directory at runtime. `assets/still.png` is the first frame
of the boot animation at 1600×900.

The greeter continues the Plymouth splash instead of starting a new picture:
the same cyber backdrop (`plymouth/backdrop.png`), the same centred still of
the animation and the same neon frame (`plymouth/frame.png`) surround the
password panel. The screen fades in when the greeter appears and fades out
again when the login succeeds, so the handover to the session does not break
the picture.

The password entry is a wide neon panel - accent border, glow, a label, the
lock icon and a blinking caret - instead of the stock one-pixel line, because
it is the one thing the user has to look at.
