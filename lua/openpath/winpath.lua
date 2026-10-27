-- openpath.winpath: Windows paths in a pane's text, under WSL.
--
-- A program run from WSL (a Windows build tool, PowerShell, a .exe's error)
-- prints `C:\Users\me\src\app.rs:12:5`, which names `/mnt/c/Users/me/...`
-- here. at() finds such a path under a cell and says which Linux path it is;
-- openpath's click and linkhover's tooltip both ask it, so the two always
-- agree on what is a path.
--
-- Taken: a drive path (`C:\...`, `C:/...`) under WSL's automount root
-- (`/etc/wsl.conf`'s `[automount] root`, `/mnt/` by default), and a
-- `\\wsl$\Distro\...` or `\\wsl.localhost\Distro\...` path into this distro,
-- which is `/...`. Another distro's or another machine's share names nothing
-- here, so it is left alone, as is a `\\wsl$` path when WSL_DISTRO_NAME is
-- unset (a server started by WSL's boot-time login has no WSL_* in its
-- environment, and the distro cannot be told then).
--
-- Converted by hand rather than with `wslpath`: a hover asks on every cell
-- the pointer rests on, and a process per rest is too dear for what is a
-- prefix swap. ranma itself calls `wslpath` for a paste, where once is fine.

local M = {}

-- "dir", "file", or nil when nothing is there.
function M.kind(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local ok, _, code = f:read(0)
  f:close()
  -- Reading a directory fails with EISDIR (21).
  if ok == nil and code == 21 then return "dir" end
  return "file"
end

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

-- WSL by its variable, else by the kernel's release (`...-microsoft-standard-WSL2`,
-- WSL1's `...-Microsoft`), as ranma's own paste tells it: the variable is
-- missing from a server WSL's boot-time login started.
local wsl_cached
function M.wsl()
  if wsl_cached == nil then
    local name = os.getenv("WSL_DISTRO_NAME")
    local release = read("/proc/sys/kernel/osrelease") or ""
    wsl_cached = (name ~= nil and name ~= "") or release:lower():find("microsoft", 1, true) ~= nil
  end
  return wsl_cached
end

-- WSL's automount root, with its trailing slash.
local function automount_root()
  local conf = read("/etc/wsl.conf")
  if not conf then return "/mnt/" end
  local section
  for line in conf:gmatch("[^\n]*") do
    line = line:gsub("[#;].*$", ""):match("^%s*(.-)%s*$")
    local s = line:match("^%[(.-)%]$")
    if s then
      section = s:lower()
    elseif section == "automount" then
      local v = line:match("^[Rr][Oo][Oo][Tt]%s*=%s*(.-)$")
      if v and v ~= "" then
        v = v:gsub('^"(.*)"$', "%1")
        return v:sub(-1) == "/" and v or v .. "/"
      end
    end
  end
  return "/mnt/"
end

local env_cached
local function env()
  if not env_cached then
    env_cached = { root = automount_root(), distro = os.getenv("WSL_DISTRO_NAME") }
  end
  return env_cached
end

-- The Linux path a Windows one names, or nil. `opts` (`root`, `distro`)
-- stands in for WSL's, for tests.
function M.to_linux(win, opts)
  opts = opts or env()
  local drive, rest = win:match("^(%a):[\\/](.*)$")
  if drive then
    rest = rest:gsub("[\\/]+", "/")
    return opts.root .. drive:lower() .. (rest == "" and "" or "/" .. rest)
  end
  local host, distro, tail = win:match("^\\\\([^\\/]+)[\\/]([^\\/]+)(.*)$")
  if not host then return nil end
  host = host:lower()
  if host ~= "wsl$" and host ~= "wsl.localhost" then return nil end
  if not opts.distro or opts.distro == "" or distro:lower() ~= opts.distro:lower() then return nil end
  tail = tail:gsub("[\\/]+", "/")
  return tail == "" and "/" or tail
end

-- How many cells a character takes: the wide ranges a terminal draws two
-- cells wide (CJK, Hangul, fullwidth forms, emoji), combining marks none.
local function cells(cp)
  if cp >= 0x300 and cp <= 0x36F or cp >= 0x200B and cp <= 0x200F or cp >= 0xFE00 and cp <= 0xFE0F then
    return 0
  end
  if cp >= 0x1100 and cp <= 0x115F or cp >= 0x2E80 and cp <= 0x303E or cp >= 0x3041 and cp <= 0xA4CF
    or cp >= 0xAC00 and cp <= 0xD7A3 or cp >= 0xF900 and cp <= 0xFAFF or cp >= 0xFE30 and cp <= 0xFE4F
    or cp >= 0xFF00 and cp <= 0xFF60 or cp >= 0xFFE0 and cp <= 0xFFE6 or cp >= 0x1F300 and cp <= 0x1F64F
    or cp >= 0x1F900 and cp <= 0x1F9FF or cp >= 0x20000 and cp <= 0x3FFFD then
    return 2
  end
  return 1
end

-- What Windows refuses in a name, which ends a path in running text. `:` is
-- not among them here: it is the drive's, and a compiler's `:12:5`.
local STOP = { ["<"] = true, [">"] = true, ['"'] = true, ["|"] = true, ["?"] = true, ["*"] = true }

-- A path, then a line in one of the ways tools print it: `:12`, `:12:5`
-- (rustc, gcc, tsc) or `(12)`, `(12,5)` (MSVC, C#).
local function split_line(s)
  local p, l = s:match("^(.-):(%d+):%d+$")
  if not p then p, l = s:match("^(.-):(%d+)$") end
  if not p then p, l = s:match("^(.-)%((%d+),%d+%)$") end
  if not p then p, l = s:match("^(.-)%((%d+)%)$") end
  return p, l and tonumber(l)
end

-- The ways one candidate may have been meant, most literal first: as
-- written, without the sentence's punctuation after it, without a line
-- after it, and without a closing bracket that was the text's (`(see
-- C:\x)`; a name may hold one too, `Program Files (x86)`, so that is last).
local function readings(s)
  local out = { { s } }
  local trimmed = s:gsub("[.,;:'`]+$", "")
  if trimmed ~= s then out[#out + 1] = { trimmed } end
  local p, l = split_line(trimmed)
  if p then out[#out + 1] = { p, l } end
  local bare = trimmed:gsub("[)%]}]+$", "")
  if bare ~= trimmed then
    out[#out + 1] = { bare }
    p, l = split_line(bare)
    if p then out[#out + 1] = { p, l } end
  end
  return out
end

-- The Windows path under cell `col` (0-based) of `text`, when it names
-- something that exists here: `{ win, path, kind, line, col, span }`, `col`
-- and `span` in cells (a tooltip's anchor), or nil. A name with spaces in it
-- (`C:\Program Files\...`) is found by trying the longest run first and
-- giving back a word at a time until something exists. A path wrapped onto
-- the next row is not followed. `opts` as for to_linux, plus `kind` for
-- tests.
function M.at(text, col, opts)
  local kind = opts and opts.kind or M.kind
  local chars, at = {}, {}
  local x, k = 0, nil
  for _, cp in utf8.codes(text) do
    chars[#chars + 1] = utf8.char(cp)
    at[#chars] = x
    local w = cells(cp)
    if not k and x + math.max(w, 1) > col then k = #chars end
    x = x + w
  end
  if not k then return nil end
  local n = #chars
  local function starts(i)
    local c, d, e = chars[i], chars[i + 1], chars[i + 2]
    local before = chars[i - 1]
    if c:match("^%a$") and d == ":" and (e == "\\" or e == "/") then
      return not (before and before:match("^[%w_]$"))
    end
    return c == "\\" and d == "\\" and before ~= "\\"
  end
  -- The start: the nearest one at or left of the cell that reaches it.
  local s
  for i = k, 1, -1 do
    if STOP[chars[i]] then return nil end
    if i < n and starts(i) then s = i break end
  end
  if not s then return nil end
  local e = s
  while e < n and not STOP[chars[e + 1]] do e = e + 1 end
  if e < k then return nil end
  for stop = e, k, -1 do
    if stop == e or chars[stop + 1]:match("^%s$") then
      local cand = table.concat(chars, "", s, stop):gsub("%s+$", "")
      for _, r in ipairs(readings(cand)) do
        local path = M.to_linux(r[1], opts)
        local what = path and kind(path)
        if what then
          return {
            win = r[1], path = path, kind = what, line = r[2],
            col = at[s], span = (at[stop] + cells(utf8.codepoint(chars[stop]))) - at[s],
          }
        end
      end
    end
  end
  return nil
end

-- What Windows opens a path with, from WSL: explorer.exe, which takes a
-- Windows path and hands a file to its default program. It exits 1 even when
-- it worked, so only a failure to start it is reported.
function M.explorer(args)
  local cmd = { "explorer.exe" }
  for _, a in ipairs(args) do cmd[#cmd + 1] = a end
  ranma.spawn(cmd, {
    timeout = 10,
    on_exit = function(r)
      if r.error then ranma.toast("openpath: could not start explorer.exe: " .. r.error, { urgent = true }) end
    end,
  })
end

-- A path as Windows writes it, which explorer.exe needs: it takes `C:/x`
-- for a search.
function M.backslashed(win)
  return (win:gsub("/", "\\"))
end

return M
