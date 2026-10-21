-- ==============================================================================
--  Virtual☆Paradise — Autostart Configuration
-- ==============================================================================
--  The session splash comes first: the greeter hands the screen to the
--  session, and the session needs a moment before the desktop has anything to
--  show. The splash keeps the theme's picture on the screen during that gap.
o.launch_on_start("session_splash.sh")

--  Default to live video wallpaper; auto-fallback to static Miku wallpaper if unavailable
o.launch_on_start("toggle_live_wallpaper.sh init")
