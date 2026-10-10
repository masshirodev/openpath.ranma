# AGENTS.md

openpath.ranma is a ranma plugin in Lua: `plugin/openpath.lua` is all of it, and
its header comment is the reference that `README.md` repeats. ranma's API is
https://github.com/masshirodev/ranma/blob/main/doc/CONFIG.md (`ranma --dump-types` prints it as LuaLS annotations).

- Push to `main`.
- A change to what it does changes the header comment and `README.md` in the
  same commit, and an option goes in the README's table.
- Check it loads: `ranma --check-config` lists every plugin and why one failed;
  `ranma lua` runs code in the live server.
- `AGENTS.local.md` (gitignored) carries what is true of one checkout on one
  machine. Never commit it.
