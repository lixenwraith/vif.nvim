local M = {}

local defaults = {
  bin = 'vif',
  args = {},
  layout = 'float',
  float = { width = 0.9, height = 0.9, border = 'rounded' },
  leave = [[<C-\><C-n>]],
}

local config = defaults

-- Keys the game reads that a global terminal-mode map commonly takes
local game_keys = { '<Esc>', '<C-h>', '<C-j>', '<C-k>', '<C-l>', '<C-w>' }

local function fail(msg)
  vim.notify('vif: ' .. msg, vim.log.levels.ERROR)
end

function M.setup(opts)
  config = vim.tbl_deep_extend('force', defaults, opts or {})
end

-- The game's binary, or nil and where to get one
function M.binary()
  local path = vim.fn.exepath(config.bin)
  if path ~= '' then
    return path
  end
  return nil,
    ('no executable `%s`: install vif from a release archive or with'):format(config.bin)
      .. ' `go install github.com/lixenwraith/vif/cmd/vif@latest`, or name its path in setup({ bin = ... })'
end

-- A float's side: a share of the room up to 1, cells above it
local function span(want, room)
  return math.max(1, math.min(room, math.floor(want <= 1 and want * room or want)))
end

local function show(buf)
  if config.layout == 'tab' then
    vim.cmd('tab sbuffer ' .. buf)
    return
  end
  local float = config.float
  local edge = float.border == 'none' and 0 or 2
  local rows, cols = vim.o.lines - vim.o.cmdheight - edge, vim.o.columns - edge
  local height, width = span(float.height, rows), span(float.width, cols)
  vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = float.border,
    height = height,
    width = width,
    row = math.floor((rows - height) / 2),
    col = math.floor((cols - width) / 2),
  })
end

-- What the game left on the screen win shows as it exited, the rows the terminal
-- wrapped joined
local function printed(buf, win)
  local width = vim.api.nvim_win_get_width(win)
  local text = ''
  for _, row in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    -- Neovim 0.11 writes this row itself once the game is gone
    if not row:find('^%[Process exited %d+%]$') then
      text = text .. row .. (vim.fn.strdisplaywidth(row) == width and '' or '\n')
    end
  end
  return vim.trim(text)
end

function M.open(args)
  if vim.fn.has('nvim-0.11') == 0 then
    return fail('vif.nvim needs Neovim 0.11 or newer')
  end
  -- Neovim settles 'termguicolors' as it finishes starting: `nvim +Vif` waits for it
  if vim.v.vim_did_enter == 0 then
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        M.open(args)
      end,
    })
    return
  end
  local bin, missing = M.binary()
  if not bin then
    return fail(missing)
  end
  -- Neovim's terminal shows 24-bit color only with 'termguicolors', which the game
  -- cannot tell from an environment that still names the terminal Neovim runs in
  local cmd = { bin, '-color', vim.o.termguicolors and 'true' or '256' }
  vim.list_extend(cmd, config.args)
  vim.list_extend(cmd, args or {})

  local buf = vim.api.nvim_create_buf(false, true)
  show(buf)
  local job = vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function(_, status)
      -- No window shows a game its player closed, and that one has nothing to say
      local win = vim.fn.win_findbuf(buf)[1]
      local text = win and printed(buf, win)
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      if text and status ~= 0 then
        -- Neovim clears the message line as it leaves terminal mode, which it does
        -- before it next waits for input: a timer says the reason after that
        vim.defer_fn(function()
          fail(text ~= '' and text or 'exited with status ' .. status)
        end, 0)
      end
    end,
  })
  -- A game no window shows would play on unseen, so it ends with its last window
  vim.api.nvim_create_autocmd('BufWinLeave', {
    buffer = buf,
    callback = function()
      vim.fn.jobstop(job)
    end,
  })
  for _, key in ipairs(game_keys) do
    vim.keymap.set('t', key, key, { buffer = buf, nowait = true })
  end
  vim.keymap.set('t', config.leave, [[<C-\><C-n>]], { buffer = buf })
  vim.cmd.startinsert()
end

return M
