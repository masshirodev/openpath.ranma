# openpath.ranma

A plugin for [ranma](https://github.com/masshirodev/ranma), the terminal tiling window manager: ctrl+click a file path or a link in a pane to open it.

## Install

With [hako](https://github.com/masshirodev/hako.ranma), in `~/.config/ranma/lua/plugins/openpath.lua`:

```lua
return { "masshirodev/openpath.ranma" }
```

Or by hand, as ranma loads any package under `pack/*/start/`:

```sh
git clone https://github.com/masshirodev/openpath.ranma ~/.config/ranma/pack/plugins/start/openpath.ranma
```

Needs: nvim and yazi (both options), `xdg-open`, and `wl-copy` (Wayland) for copying an image's content.

## What it does

```text
  ctrl+click         a file opens in nvim in a new pane (at its line, for
                     `src/app.rs:120:5` as compilers print them); a
                     directory in yazi; an image, a PDF or anything else
                     that is not text with xdg-open.
  ctrl+right-click   a list: nvim, its folder in yazi or with xdg-open
                     (the desktop's file manager), xdg-open, copy the
                     file's content (text as text, an image as an image you
                     can paste into a browser or a chat), copy the path.
                     On a directory: yazi, xdg-open, copy the path.
A path is taken as the pane's shell would: relative to its directory, `~`
for home. Text that is not an existing file or directory is left alone, so
the click does nothing there. Alt+click works the same as Ctrl+click.
The editor and the file manager open in a tiled pane, or in a float when
`openpath.open_in` says so (`openpath.float_size` percent of the workspace;
needs a ranma with `ranma.open`, and an older one opens a tile).

A link (a URL in the text, or an OSC 8 link whose text says something else,
like a `PR #45` that points at the pull request) is taken first:
  ctrl+click         opens it with xdg-open; a file:// link is a path.
  ctrl+right-click   a list: open it, copy the address, copy the text.
Opening happens where ranma runs, so from a terminal that came over SSH a
ctrl+click copies the address instead and says so.

ranma's plugin API: https://github.com/masshirodev/ranma/blob/main/doc/CONFIG.md ("Hooks": click).
```

## Options

In ranma's settings panel under `openpath`, or with hako's `opts` (`{ "masshirodev/openpath.ranma", opts = { ... } }`), or `ranma.set { openpath = { ... } }`.

| Option | Default | |
| --- | --- | --- |
| `openpath.editor` | `"nvim"` | What a text file opens in; +LINE is passed when the path names a line. |
| `openpath.files` | `"yazi"` | What a directory opens in. |
| `openpath.open_in` | `"tile"` | Whether the editor and the file manager open in a tiled pane (`"tile"`) or a floating one (`"float"`). |
| `openpath.float_size` | `80` | The float's width and height, in percent of the workspace (10 to 100), when opening in a float. |

## License

MIT or Apache-2.0, as ranma.
