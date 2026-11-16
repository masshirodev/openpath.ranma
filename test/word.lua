-- The path finder for a click, against a stand-in tree: `lua test/word.lua`
-- from the checkout (Lua 5.4, no ranma needed). Exits 1 on a failure.
--
-- The tree is made under a temporary directory and removed at the end; it
-- is the pane's directory, and `~` is its `home/`.

package.path = "lua/?.lua;" .. package.path
local W = require("openpath.word")
local kind = require("openpath.winpath").kind

local function sh(cmd)
  local p = assert(io.popen(cmd))
  local out = p:read("a")
  p:close()
  return (out:gsub("\n$", ""))
end

local S = sh("mktemp -d")
assert(S ~= "", "mktemp -d failed")
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
for _, d in ipairs { "doc/handoffs", "home/My Docs", "src" } do
  sh("mkdir -p " .. q(S .. "/" .. d))
end
for _, f in ipairs { "doc/handoffs/HR Import.zip", "home/My Docs/notes.md", "src/app.rs", "src/写真 猫.png", "src/it's.txt" } do
  sh("touch " .. q(S .. "/" .. f))
end

local opts = { cwd = S, home = S .. "/home", kind = kind }

local fails = 0
local function strip(p) return p and (p:sub(1, #S) == S and p:sub(#S + 1) or p) end

-- `col` is the 0-based cell clicked; `want` the path without the tree's
-- prefix, or nil when the click should find nothing.
local function t(text, col, want, line)
  local path, _, l = W.at(text, col, opts)
  local got = strip(path)
  if got ~= want or l ~= line then
    fails = fails + 1
    print(("FAIL  %q at %d: got %s line %s, want %s line %s"):format(text, col,
      tostring(got), tostring(l), tostring(want), tostring(line)))
  end
end

local function col(text, needle) return assert(text:find(needle, 1, true), needle) - 1 end

-- The case that started it: a name with a space, between backticks.
local s = "The handoff is `doc/handoffs/HR Import.zip`, unzip it."
t(s, col(s, "HR"), "/doc/handoffs/HR Import.zip")
t(s, col(s, "Import"), "/doc/handoffs/HR Import.zip")
t(s, col(s, "doc/"), "/doc/handoffs/HR Import.zip")
t(s, col(s, "unzip"), nil)
-- Two spans on a line: between them is outside both.
s = "see `src/app.rs` and then `doc/handoffs/HR Import.zip`"
t(s, col(s, "app"), "/src/app.rs")
t(s, col(s, "then"), nil)
t(s, col(s, "Import"), "/doc/handoffs/HR Import.zip")
-- A line after it, inside the span.
s = "at `src/app.rs:12:5`"
t(s, col(s, "app"), "/src/app.rs", 12)
-- Quotes, and `~`.
s = [[open "~/My Docs/notes.md" now]]
t(s, col(s, "Docs"), "/home/My Docs/notes.md")
s = [[open '~/My Docs/notes.md' now]]
t(s, col(s, "notes"), "/home/My Docs/notes.md")
-- An apostrophe does not throw quotes off: the plain word still opens.
s = "it's in src/app.rs"
t(s, col(s, "app"), "/src/app.rs")
-- A name with an apostrophe, in backticks.
s = "`src/it's.txt`"
t(s, col(s, "txt"), "/src/it's.txt")
-- A shell's escaped space.
s = [[ls: doc/handoffs/HR\ Import.zip]]
t(s, col(s, "Import"), "/doc/handoffs/HR Import.zip")
t(s, col(s, "doc"), "/doc/handoffs/HR Import.zip")
-- A span that is not a path falls back to the word under the click.
s = "`cat src/app.rs`"
t(s, col(s, "app"), "/src/app.rs")
-- Plain words, as before.
s = "error: src/app.rs:120:5: bad"
t(s, col(s, "src"), "/src/app.rs", 120)
t(s, col(s, "bad"), nil)
s = "see src/app.rs."
t(s, col(s, "app"), "/src/app.rs")
-- Cells, not bytes: wide characters before the click.
s = "写真 `src/写真 猫.png` and src/app.rs"
t(s, 10, "/src/写真 猫.png")
t(s, 31, "/src/app.rs")
-- Past the end of the line.
t("src/app.rs", 40, nil)

sh("rm -rf " .. q(S))
if fails > 0 then
  print(fails .. " failed")
  os.exit(1)
end
print("all passed")
