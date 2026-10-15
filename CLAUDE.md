# Notes for working on EFTP_XL

- **Releases carry the program.** `bin/` and `dist/` are build output,
  never committed. `VERSION` in `src/main.c` holds the last release (a
  build shows `x.y-dev`; `make RELEASE=1` shows `x.y`). A release: raise
  `VERSION`, commit, push, then run the Release workflow on main with the
  notes; `.github/workflows/release.yml` builds cc65 at `CC65_REV` and
  the program, tags vX.Y and publishes `EFTPXL.XEX`. Never reuse a number.
- **The name** reads "AERA | Erez Yaary" wherever it is given: copyright
  lines (`Copyright (C) 2026 AERA | Erez Yaary`), the docs, and as the
  author of every commit:
  `git commit --author="AERA | Erez Yaary <yaary@me.com>"`, with Claude as
  the signing committer (AERA-Atari, `standards/GITHUB-IDENTITY.md`).
