-- ==============================================================================
--  Virtual☆Paradise — Autostart Configuration
-- ==============================================================================
--  The session splash comes first: the greeter hands the screen to the
--  session, and the session needs a moment before the desktop has anything to
--  show. The splash keeps the theme's picture on the screen during that gap.
o.launch_on_start("session_splash.sh")

--  The window death daemon keeps the close burst warm: a resident shell
--  maps the burst in a single frame, so the glitch and the close land in
--  the same breath instead of the burst trailing the window.
o.launch_on_start("vp_death_daemon.sh")

--  Default to live video wallpaper; auto-fallback to static Miku wallpaper if unavailable
o.launch_on_start("toggle_live_wallpaper.sh init")

--  Login chime. vp-sound.sh is best-effort: it exits silently when the player
--  or the sound pack is missing, and `~/.local/state/virtual-paradise/sound-off`
--  turns every theme sound off.
o.launch_on_start("vp-sound.sh login")
