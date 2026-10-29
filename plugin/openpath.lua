-- openpath: Ctrl+click a file path or a link in a pane to open it.
--
--   ctrl+click         a file opens in nvim in a new pane (at its line, for
--                      `src/app.rs:120:5` as compilers print them); a
--                      directory in yazi; an image, a PDF or anything else
--                      that is not text with xdg-open.
--   ctrl+right-click   a list: nvim, its folder in yazi or with xdg-open
--                      (the desktop's file manager), xdg-open, copy the
--                      file's content (text as text, an image as an image you
--                      can paste into a browser or a chat), copy the path.
--                      On a directory: yazi, xdg-open, copy the path.
-- A path is taken as the pane's shell would: relative to its directory, `~`
-- for home. Text that is not an existing file or directory is left alone, so
-- the click does nothing there. Alt+click works the same as Ctrl+click.
-- The editor and the file manager open in a tiled pane, or in a float when
-- `openpath.open_in` says so (`openpath.float_size` percent of the workspace;
-- needs a ranma with `ranma.open`, and an older one opens a tile).
--
-- Over ssh, in a ranma with a ranma around it (the PC's, with this one on
-- the VPS), a picture, a PDF, audio or video is fetched to the machine at
-- the keyboard and opened there (`ranma.open_here`), since there is no screen
-- here: ctrl+click, and "open on this desktop" in the list. Other kinds are
-- not carried. Needs a ranma with `ranma.open_here` on both sides.
--
-- Under WSL, a Windows path is the Linux path it names: `C:\Users\me\a.rs:12`
-- (or `C:/...`, or `(12,5)` as MSVC prints a line) is `/mnt/c/Users/me/a.rs`,
-- under WSL's automount root, and `\\wsl$\Distro\...` or
-- `\\wsl.localhost\Distro\...` into this distro is `/...`. A name with spaces
-- (`C:\Program Files\...`) is found whole. It opens as any path does, except
-- that what is not text opens with Windows (explorer.exe), and the list adds
-- "open with Windows" (on a file), "show in Explorer" or "open in Explorer",
-- and "copy the Windows path" beside the Linux one. `openpath.windows_paths`
-- turns it off; off WSL it does nothing. linkhover.ranma shows the Linux path
-- in a tooltip.
--
-- A link (a URL in the text, or an OSC 8 link whose text says something else,
-- like a `PR #45` that points at the pull request) is taken first:
--   ctrl+click         opens it with xdg-open; a file:// link is a path.
--   ctrl+right-click   a list: open it, copy the address, copy the text.
-- A file:// link to a path not on this machine says "not found here" (on
-- ctrl+click, and as the list's title), since there is nothing to open.
-- Opening happens where ranma runs, so from a terminal that came over SSH a
-- ctrl+click copies the address instead and says so.
--
-- ranma's plugin API: https://github.com/masshirodev/ranma/blob/main/doc/CONFIG.md ("Hooks": click).
--

ranma.option("openpath.editor", {
  type = "string", default = "nvim",
  name = "Editor", desc = "What a text file opens in; +LINE is passed when the path names a line.",
})
ranma.option("openpath.files", {
  type = "string", default = "yazi",
  name = "File manager", desc = "What a directory opens in.",
})
ranma.option("openpath.open_in", {
  type = "enum", choices = { "tile", "float" }, default = "tile",
  name = "Open in", desc = "Whether the editor and the file manager open in a tiled pane or a floating one.",
})
ranma.option("openpath.float_size", {
  type = "int", min = 10, max = 100, step = 5, default = 80,
  name = "Float size", desc = "The float's width and height, in percent of the workspace, when opening in a float.",
})
ranma.option("openpath.windows_paths", {
  type = "bool", default = true,
  name = "Windows paths", desc = "Under WSL, take a Windows path (C:\\..., \\\\wsl$\\...) as the Linux path it names.",
})

-- This package's lua/ is on require's path once it is loaded.
local W = require("openpath.winpath")

local HOME = os.getenv("HOME") or ""

-- Characters a path is made of, as a compiler or `ls` prints one.
local PATHCHAR = "[%w%._%-/~+@,=]"

-- The path-like word around column `col` (0-based) of `text`, with a
-- `:line[:col]` after it split off.
local function word_at(text, col)
  local i = col + 1
  local function part(c) return c:match(PATHCHAR) or c == ":" end
  if i > #text or not part(text:sub(i, i)) then return nil end
  local a, b = i, i
  while a > 1 and part(text:sub(a - 1, a - 1)) do a = a - 1 end
  while b < #text and part(text:sub(b + 1, b + 1)) do b = b + 1 end
  local w = text:sub(a, b):gsub("^[:,]+", ""):gsub("[.,:;]+$", "")
  local path, line = w:match("^(.-):(%d+):%d+$")
  if not path then path, line = w:match("^(.-):(%d+)$") end
  return path or w, line and tonumber(line)
end

local function resolve(path, cwd)
  if path:sub(1, 2) == "~/" or path == "~" then return HOME .. path:sub(2) end
  if path:sub(1, 1) == "/" then return path end
  return (cwd or HOME) .. "/" .. path
end

local kind = W.kind

local NOT_TEXT = { png = true, jpg = true, jpeg = true, gif = true, webp = true, pdf = true,
  mp4 = true, mkv = true, webm = true, mp3 = true, flac = true, zip = true }

local function is_text(path)
  local ext = path:match("%.(%w+)$")
  return not (ext and NOT_TEXT[ext:lower()])
end

local function quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- ranma.open puts a float straight into the floating layer, so the tiles
-- are never split to make room for it. A ranma without it opens a tile.
local function open_pane(cmd)
  if ranma.get("openpath.open_in") == "float" and ranma.has("open") then
    ranma.open { command = cmd, float = ranma.get("openpath.float_size") }
  else
    ranma.action("exec " .. cmd)
  end
end

local function open_editor(path, line)
  local cmd = ranma.get("openpath.editor")
  if line then cmd = cmd .. " +" .. line end
  open_pane(cmd .. " " .. quote(path))
end

local function open_dir(path)
  open_pane(ranma.get("openpath.files") .. " " .. quote(path))
end

local function xdg(path)
  ranma.spawn({ "xdg-open", path }, { timeout = 10 })
end

-- Whether the screen is on another machine, with a ranma there to open
-- files for this one.
local function far()
  return ranma.has("open_here") and ranma.client().outer
end

-- A file opened with the desktop's opener: here, or on the machine at the
-- keyboard when that is another one.
local function open_file(path)
  if far() then ranma.open_here(path) else xdg(path) end
end

-- Text goes through ranma.copy (OSC 52), which reaches this desktop's
-- clipboard over SSH too. An image or any other binary goes in with its own
-- MIME type, so it pastes as an image: that is wl-copy, on this machine only.
local MAX_TEXT = 1024 * 1024

local function copy_binary(path)
  local q = quote(path)
  -- setsid: wl-copy stays behind serving the clipboard, and must not share
  -- the process group ranma kills when a job is stopped.
  ranma.spawn("setsid -f wl-copy --type \"$(file --mime-type -b " .. q .. ")\" < " .. q, {
    on_exit = function(r)
      if r.error or r.code ~= 0 then
        ranma.toast("openpath: could not copy: " .. (r.error or r.stderr or "wl-copy failed"), { urgent = true })
      else
        ranma.toast("copied " .. path:match("[^/]*$"))
      end
    end,
  })
end

local function copy_content(path)
  if not is_text(path) then return copy_binary(path) end
  local f = io.open(path, "rb")
  if not f then return ranma.toast("openpath: cannot read " .. path, { urgent = true }) end
  local text = f:read("a")
  f:close()
  -- Text by its name but not by its bytes: copy it as what it is.
  if text:find("\0", 1, true) then return copy_binary(path) end
  if #text > MAX_TEXT then
    return ranma.toast("openpath: over 1 MiB, too big for the clipboard escape", { urgent = true })
  end
  ranma.copy(text)
  local _, lines = text:gsub("\n", "")
  ranma.toast("copied " .. path:match("[^/]*$") .. " (" .. lines .. " lines)")
end

-- The link under the click, as ranma's hints find it, or nil.
local function link_at(e)
  local p = ranma.pane(e.pane)
  return p and p:link_at(e.line, e.col)
end

-- A file:// link names a path on this machine (its host, if any, is this one).
local function file_path(url)
  local path = url:match("^file://[^/]*(/.*)$")
  return path and path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
end

local function copy_url(url)
  ranma.copy(url)
  ranma.toast("copied " .. url)
end

local function open_url(url)
  if ranma.client().remote then
    copy_url(url)
    return ranma.toast("opening would happen on the server, not here: copied instead")
  end
  xdg(url)
end

local on_path

local function on_link(e, l)
  local path = file_path(l.url)
  local k = path and kind(path)
  if k then
    on_path(e, path, k, nil)
    return true
  end
  -- A file:// link to nothing on this machine: it may be on another one, or
  -- gone, and xdg-open would fail without a word.
  local missing
  if path then
    local shown = HOME ~= "" and path:gsub("^" .. HOME:gsub("%p", "%%%0") .. "/", "~/") or path
    missing = "not found here: " .. shown
  end
  if e.button == "left" then
    if missing then ranma.toast(missing) else open_url(l.url) end
  elseif e.button == "right" then
    local items = {
      { label = "open with xdg-open", act = "open" },
      { label = "copy the address", detail = l.url, act = "copy" },
    }
    local shown = l.text or ""
    if shown ~= "" and shown ~= l.url then
      items[#items + 1] = { label = "copy the text", detail = shown, act = "text" }
    end
    ranma.picker {
      title = missing or l.url,
      items = items,
      on_select = function(item)
        if item.act == "open" then open_url(l.url)
        elseif item.act == "copy" then copy_url(l.url)
        elseif item.act == "text" then ranma.copy(shown) ranma.toast("copied " .. shown) end
      end,
    }
  end
  return true
end

-- The Windows path under the click, under WSL, or nil.
local function windows_at(text, col)
  if not (ranma.get("openpath.windows_paths") and W.wsl()) then return nil end
  return W.at(text, col)
end

local function target(e)
  local p = ranma.pane(e.pane)
  if not p then return nil end
  local text = p:lines(e.line, e.line)[1]
  if not text then return nil end
  local w = windows_at(text, e.col)
  if w then return w.path, w.kind, w.line, w.win end
  local word, line = word_at(text, e.col)
  if not word or word == "" then return nil end
  local path = resolve(word, p:cwd())
  local k = kind(path)
  if not k then return nil end
  return path, k, line
end

-- `win` is the Windows path the text said, when it said one.
function on_path(e, path, k, line, win)
  if e.button == "left" then
    if k == "dir" then
      open_dir(path)
    elseif is_text(path) then
      open_editor(path, line)
    elseif win then
      W.explorer({ W.backslashed(win) })
    else
      open_file(path)
    end
  elseif e.button == "right" then
    local dir = k == "dir" and path or path:match("^(.*)/[^/]*$") or path
    local files = ranma.get("openpath.files")
    local items
    if k == "dir" then
      items = {
        { label = "open in " .. files, act = "dir" },
        { label = "open with xdg-open", act = "xdg" },
        { label = "copy the path", detail = path, act = "copy" },
      }
    else
      items = {
        { label = "open in " .. ranma.get("openpath.editor"), act = "edit" },
        { label = "open its folder in " .. files, detail = dir, act = "dir" },
        { label = "open its folder with xdg-open", detail = dir, act = "xdg-dir" },
        { label = far() and "open on this desktop" or "open with xdg-open", act = "xdg" },
        { label = "copy content", detail = is_text(path) and "as text" or "as " .. ((path:match("%.(%w+)$") or "a file"):lower()) .. ", for pasting", act = "content" },
        { label = "copy the path", detail = path, act = "copy" },
      }
    end
    if win then
      local winned = W.backslashed(win)
      -- Windows' own opener, before the copies: under WSL xdg-open is
      -- often missing, and these are what work.
      local opens = k == "dir"
        and { { label = "open in Explorer", act = "win-open" } }
        or {
          { label = "open with Windows", detail = "its default program", act = "win-open" },
          { label = "show in Explorer", act = "win-select" },
        }
      local at = #items
      while at > 0 and (items[at].act == "copy" or items[at].act == "content") do at = at - 1 end
      for i, it in ipairs(opens) do table.insert(items, at + i, it) end
      items[#items + 1] = { label = "copy the Windows path", detail = winned, act = "copy-win" }
    end
    ranma.picker {
      title = path,
      items = items,
      on_select = function(item)
        if item.act == "edit" then open_editor(path, line)
        elseif item.act == "dir" then open_dir(dir)
        elseif item.act == "xdg" then
          if k == "dir" then xdg(path) else open_file(path) end
        elseif item.act == "xdg-dir" then xdg(dir)
        elseif item.act == "content" then copy_content(path)
        elseif item.act == "copy" then ranma.copy(path)
        elseif item.act == "win-open" then W.explorer({ W.backslashed(win) })
        elseif item.act == "win-select" then W.explorer({ "/select," .. W.backslashed(win) })
        elseif item.act == "copy-win" then ranma.copy(W.backslashed(win)) end
      end,
    }
  end
end

ranma.on("click", function(e)
  local l = link_at(e)
  if l and on_link(e, l) then return end
  local path, k, line, win = target(e)
  if path then on_path(e, path, k, line, win) end
end)
