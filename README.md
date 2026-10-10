# openpath.ranma

A plugin for [ranma](https://github.com/masshirodev/ranma), the terminal tiling window manager: ctrl+click a file path in a pane to open it.

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
  ctrl+right-click   a list: nvim, yazi on its folder, xdg-open, copy the
                     file's content (text as text, an image as an image you
                     can paste into a browser or a chat), copy the path.
A path is taken as the pane's shell would: relative to its directory, `~`
for home. Text that is not an existing file or directory is left alone, so
the click does nothing there. Alt+click works the same as Ctrl+click.

ranma's plugin API: https://github.com/masshirodev/ranma/blob/main/doc/CONFIG.md ("Hooks": click).
```

## Options

In ranma's settings panel under `openpath`, or with hako's `opts` (`{ "masshirodev/openpath.ranma", opts = { ... } }`), or `ranma.set { openpath = { ... } }`.

| Option | Default | |
| --- | --- | --- |
| `openpath.editor` | `"nvim"` | What a text file opens in; +LINE is passed when the path names a line. |
| `openpath.files` | `"yazi"` | What a directory opens in. |

## License

MIT or Apache-2.0, as ranma.
