# UI golden baselines

`1920x1080-scale1/` is a reference capture of the Settings card on the
reference machine (1920×1080, scale 1.0), cropped to the settings card so the desktop and live bar clock are excluded.

Run it against a live session:

```bash
./tools/ui-smoke.sh --baseline tests/golden/1920x1080-scale1 \
  --crop '1490,50 420x880' --threshold 1000
```

The first run into an empty directory saves a baseline; later runs diff. A
machine with a different screen size, scale, font or theme palette should
create its own baseline under a matching directory instead of overwriting this
one. This check is intentionally manual and is not part of the CI suite.
