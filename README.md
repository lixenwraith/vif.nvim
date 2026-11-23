# vif.nvim

Play [vif](https://github.com/lixenwraith/vif), the vi-motion typing shooter, in a
Neovim terminal buffer. `:Vif` opens the game in a floating window or a tab page
and gets out of its way.

## Requirements

- Neovim 0.11 or newer.
- The `vif` binary on `PATH`, or its path in `setup`. The plugin never downloads
  it: get it from a [release archive](https://github.com/lixenwraith/vif/releases)
  or with `go install github.com/lixenwraith/vif/cmd/vif@latest`, and from the
  AUR (`vif`) or FreeBSD ports (`games/vif`) once it is packaged there.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'lixenwraith/vif.nvim', cmd = 'Vif', opts = {} }
```

With Neovim 0.12's `vim.pack`:

```lua
vim.pack.add({ 'https://github.com/lixenwraith/vif.nvim' })
```

Or clone it into a `pack/*/start/` directory of `'packpath'`. `:checkhealth vif`
says whether Neovim, the binary and the colors are in order.

## Play

```vim
:Vif
:Vif -s td
:Vif -join=vifs://host:7777/game
:Vif -spectate=vifs://host:7777/game
```

Arguments go to the game as on a command line; `vif -h` in a shell lists them.
The game leaves as in a terminal, with `:q` or Ctrl-Q, and its window closes with
it. When it exits with an error, what it printed is shown as an error message.
Closing the window ends the game.

## Options

`setup` is optional. These are the defaults:

```lua
require('vif').setup({
  bin = 'vif',                -- the game: a name on PATH, or a path
  args = {},                  -- arguments every game starts with, as { '-mute' }
  layout = 'float',           -- or 'tab'
  float = {
    width = 0.9,              -- a share of the editor up to 1, cells above it
    height = 0.9,
    border = 'rounded',       -- as nvim_open_win() takes it, 'none' for none
  },
  leave = [[<C-\><C-n>]],     -- leaves terminal mode; i goes back to the game
})
```

`require('vif').open({ '-s', 'td' })` is `:Vif -s td` from Lua.

## Keys

In terminal mode every key goes to the game. The game's buffer maps Esc, Ctrl-H,
Ctrl-J, Ctrl-K, Ctrl-L and Ctrl-W to themselves, so a global terminal-mode map of
one of them (`tnoremap <Esc> <C-\><C-n>`, window navigation) does not take it from
the game. The `leave` key goes to Normal mode with the game still running.

## In a Neovim terminal

The game plays as in a terminal of its own, with these differences:

- **Colors.** Neovim's terminal shows 24-bit color only with `'termguicolors'`, so
  the game is started with `-color true` when the option is on and `-color 256`
  when it is off.
- **Held keys.** Neovim's terminal passes on no key release, so a key held down is
  a run of taps at the keyboard's repeat rate, as in tmux.
- **Mouse.** Presses, drags and the wheel reach the game at the cell under the
  pointer. The pointer moving with no button down reaches it only with
  `'mousemoveevent'` set, which the game's cursor needs to follow the pointer.

`:help vif` has the rest.

## Tests

```sh
nvim --headless -u NONE -l tests/run.lua
```

## License

BSD-3-Clause.
