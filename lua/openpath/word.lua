-- The path under a click, in a line of a pane: a plain word as a compiler or
-- `ls` prints one, or a name with spaces in it when the text marks where it
-- starts and ends. Plain Lua, so test/word.lua runs it without ranma.

local M = {}

-- Characters a path is made of, as a compiler or `ls` prints one.
local PATHCHAR = "^[%w%._%-/~+@,=]$"

-- How many cells a character takes: the wide ranges a terminal draws two
-- cells wide (CJK, Hangul, fullwidth forms, emoji), combining marks none.
-- The same table as winpath.lua's.
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

-- `text` as a list of characters, and the index of the one that covers cell
-- `col` (0-based), or nil past the end. Cells, not bytes: a Japanese name
-- before the click would otherwise move it.
local function split(text, col)
  local chars, k, x = {}, nil, 0
  if not utf8.len(text) then
    -- Not UTF-8: one byte, one cell.
    for i = 1, #text do chars[i] = text:sub(i, i) end
    return chars, (col < #text) and col + 1 or nil
  end
  for _, cp in utf8.codes(text) do
    chars[#chars + 1] = utf8.char(cp)
    local w = cells(cp)
    if not k and x + math.max(w, 1) > col then k = #chars end
    x = x + w
  end
  return chars, k
end

-- A path, then the line a compiler prints after it: `:12` or `:12:5`.
local function split_line(s)
  local p, l = s:match("^(.-):(%d+):%d+$")
  if not p then p, l = s:match("^(.-):(%d+)$") end
  return p or s, l and tonumber(l)
end

function M.resolve(path, cwd, home)
  if path:sub(1, 2) == "~/" or path == "~" then return home .. path:sub(2) end
  if path:sub(1, 1) == "/" then return path end
  return (cwd or home) .. "/" .. path
end

-- The text between the marks around character `k`, or nil when it is not
-- inside a pair. Backticks pair up in order along the line, as Markdown's
-- code spans do, so a click between two spans is outside both. Quotes do
-- not: an apostrophe (`doesn't`) would put every pair after it off by one,
-- so a quote takes the nearest one of its kind on each side.
local function between(chars, k, mark)
  if chars[k] == mark then return nil end
  local open
  if mark == "`" then
    for i = 1, k - 1 do
      if chars[i] == "`" then open = (open == nil) and i or nil end
    end
  else
    for i = k - 1, 1, -1 do
      if chars[i] == mark then open = i break end
    end
  end
  if not open then return nil end
  for i = k + 1, #chars do
    if chars[i] == mark then
      local s = table.concat(chars, "", open + 1, i - 1):match("^%s*(.-)%s*$")
      return s ~= "" and s or nil
    end
  end
  return nil
end

-- The plain word around character `k`. `\ ` (a space escaped as a shell
-- prints one, `HR\ Import.zip`) is part of it, and comes back a space.
local function word(chars, k)
  local function part(i)
    local c = chars[i]
    if not c then return false end
    if c:match(PATHCHAR) or c == ":" then return true end
    if c == "\\" then return chars[i + 1] == " " end
    if c == " " then return chars[i - 1] == "\\" end
    return false
  end
  if not part(k) then return nil end
  local a, b = k, k
  while a > 1 and part(a - 1) do a = a - 1 end
  while b < #chars and part(b + 1) do b = b + 1 end
  local w = table.concat(chars, "", a, b):gsub("\\ ", " ")
  return (w:gsub("^[:,]+", ""):gsub("[.,:;]+$", ""))
end

-- The path under cell `col` (0-based) of `text` that names something that
-- exists: `path, kind, line`, or nil. A name with spaces in it is found
-- whole when it sits between backticks or quotes (`doc/HR Import.zip`), or
-- with its spaces escaped; tried before the plain word, and kept only when
-- it exists. `opts`: `cwd` and `home` resolve a relative path, `kind` says
-- what is at one (winpath's, for tests a stand-in).
function M.at(text, col, opts)
  local chars, k = split(text, col)
  if not k then return nil end
  local function try(s)
    if not s or s == "" then return nil end
    for _, cand in ipairs { { s }, { split_line(s) } } do
      if cand[1] ~= "" then
        local path = M.resolve(cand[1], opts.cwd, opts.home)
        local what = opts.kind(path)
        if what then return path, what, cand[2] end
      end
    end
    return nil
  end
  for _, mark in ipairs { "`", '"', "'" } do
    local path, what, line = try(between(chars, k, mark))
    if path then return path, what, line end
  end
  return try(word(chars, k))
end

return M
