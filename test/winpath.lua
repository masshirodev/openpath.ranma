-- The Windows path finder, against a stand-in WSL tree: `lua test/winpath.lua`
-- from the checkout (Lua 5.4, no ranma needed). Exits 1 on a failure.
--
-- The tree is made under a temporary directory and removed at the end, and
-- `opts` points the finder at it: `root` stands for WSL's automount root, and
-- `kind` sends a `\\wsl$` path (a path from `/`) into the tree too.

package.path = "lua/?.lua;" .. package.path
local W = require("openpath.winpath")

local function sh(cmd)
  local p = assert(io.popen(cmd))
  local out = p:read("a")
  p:close()
  return (out:gsub("\n$", ""))
end

local S = sh("mktemp -d")
assert(S ~= "", "mktemp -d failed")
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
for _, d in ipairs { "mnt/c/Users/me/src", "mnt/c/Program Files (x86)/App", "mnt/d/写真", "distro/home/me" } do
  sh("mkdir -p " .. q(S .. "/" .. d))
end
for _, f in ipairs { "mnt/c/Users/me/src/app.rs", "mnt/c/Program Files (x86)/App/run log.txt", "mnt/d/写真/猫.png", "mnt/c/Users/me/x.cs" } do
  sh("touch " .. q(S .. "/" .. f))
end

local opts = {
  root = S .. "/mnt/",
  distro = "Arch",
  kind = function(p)
    if p:sub(1, #S) ~= S then p = S .. "/distro" .. p end
    return W.kind(p)
  end,
}

local fails = 0
local function strip(p) return p and (p:sub(1, #S) == S and p:sub(#S + 1) or p) end

-- `want` is the path (without the tree's prefix) or nil, and its line, col
-- and span when given.
local function t(text, col, want, line, at, span)
  local r = W.at(text, col, opts)
  local got = r and strip(r.path)
  local ok = got == want
  if ok and r then
    ok = r.line == line and (at == nil or (r.col == at and r.span == span))
  end
  if not ok then
    fails = fails + 1
    print(("FAIL  %q at %d: got %s line %s col %s span %s"):format(text, col, tostring(got),
      tostring(r and r.line), tostring(r and r.col), tostring(r and r.span)))
  end
end

-- A compiler's line and column, and the cells the path takes.
t([[error at C:\Users\me\src\app.rs:12:5: bad]], 12, "/mnt/c/Users/me/src/app.rs", 12, 9, 28)
t([[error at C:\Users\me\src\app.rs:12:5: bad]], 2, nil)
t([[error at C:\Users\me\src\app.rs:12:5: bad]], 40, nil)
t([[C:/Users/me/src/app.rs]], 0, "/mnt/c/Users/me/src/app.rs", nil)
-- MSVC's and C#'s `(line,col)`.
t([[x.cs: C:\Users\me\x.cs(10,3): error CS1002]], 10, "/mnt/c/Users/me/x.cs", 10)
-- Spaces and brackets in names, quoted and in parentheses.
t([[see "C:\Program Files (x86)\App\run log.txt" now]], 30, "/mnt/c/Program Files (x86)/App/run log.txt", nil)
t([[see "C:\Program Files (x86)\App\run log.txt" now]], 46, nil)
t([[(in C:\Program Files (x86)\App)]], 10, "/mnt/c/Program Files (x86)/App", nil)
-- Wide characters take two cells each.
t([[画像 D:\写真\猫.png です]], 5, "/mnt/d/写真/猫.png", nil, 5, 14)
t([[画像 D:\写真\猫.png です]], 16, "/mnt/d/写真/猫.png", nil)
t([[画像 D:\写真\猫.png です]], 19, nil)
-- This distro's share is `/`; another's, or another machine's, is nothing.
t([[\\wsl$\Arch\home\me]], 3, "/home/me", nil)
t([[\\wsl.localhost\arch\home\me\]], 20, "/home/me/", nil)
t([[\\wsl$\Ubuntu\home\me]], 3, nil)
t([[\\server\share\x]], 3, nil)
-- Not a drive, and a path to nothing.
t([[abc:\nope]], 3, nil)
t([[C:\Users\nothere]], 4, nil)

assert(W.to_linux([[C:\]], opts) == S .. "/mnt/c")
assert(W.to_linux([[\\wsl$\Arch\x]], { root = "/mnt/" }) == nil, "no distro known, no share")
assert(W.backslashed("C:/a/b") == [[C:\a\b]])

sh("rm -rf " .. q(S))
if fails > 0 then
  print(fails .. " failed")
  os.exit(1)
end
print("winpath: all passed")
