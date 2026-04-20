# El: Elixir/OTP Control Plane

Bootstrap patterns for zombie features (headless Claude sessions).

## Running El

Two modes — never mix them up.

### Installed (brew)
- Binary: `/opt/homebrew/bin/el` (Burrito release)
- This is the real `el` — what the el skill uses
- Install: `brew reinstall limadelic/el/el`
- Publish: `./scripts/release.sh` (bob `release` command)

### Dev (local)
- Binary: `./el` (escript, project root only)
- Build: `mix escript.build` (bob `build` command)
- Used by: tests, bob, local development
- Scoped to this project folder only

## Versioning

- Current release line: 0.1.x
- NEVER bump to 0.2. Stay on 0.1.xxx
- Version bumps only when explicitly requested by the user
