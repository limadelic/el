# El

- This is El source
- `el` if confused bout it

# DEV SETUP

- `./el` is a mix release wrapper (NOT an escript), exec to `_build/dev/rel/el/bin/el_wrapper`
- `el` (`/opt/homebrew/bin/el`) is the installed prod release
- Two nodes: `el_dev@127.0.0.1` (dev, DEV=1) and `el@127.0.0.1` (prod)
- After code changes: `mix release --overwrite` to rebuild
- Cukes: `bundle exec cucumber -p dev`
- Kill stale processes: `pkill -f beam.smp; pkill -f epmd`

# BOB

- dont give bob instructions he know what todo

# CURRENT VERSION

- Current release line: 0.1.x
- NEVER bump to 0.2. Stay on 0.1.xxx

# RELATED PROJECTS

- **El** (this repo) - Elixir/OTP control plane. GenServers, Ports, PTY, distributed Erlang, OTP supervisors.
- **Dude** (~/.claude/) - the product layer El serves. Skills, agents, workflows, the Ruby gem.
- **Claude Code** ~/dev/ext/claude-code/ (READ ONLY) - the platform. Reverse engineer to find seams, APIs, file formats we can hook into.

# GIT

- always code in wip branch
- only 1 branch besides main 
- dont make branches
- dont commit to main