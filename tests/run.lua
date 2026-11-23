-- nvim --headless -u NONE -l tests/run.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
vim.cmd.runtime('plugin/vif.lua')

local dir = vim.fn.tempname()
vim.fn.mkdir(dir)
vim.env.VIF_TEST_DIR = dir

local said = {}
vim.notify = function(msg, level)
  said[#said + 1] = { msg = msg, level = level or vim.log.levels.INFO }
end

local function recorded(name)
  return vim.fn.readfile(dir .. '/' .. name)
end

local function same(got, want)
  assert(vim.deep_equal(got, want), ('got %s, want %s'):format(vim.inspect(got), vim.inspect(want)))
end

local function wait(what, cond)
  assert(vim.wait(5000, cond), what)
end

-- gone waits for the game's buffer to go, and for what its exit put off saying
local function gone(buf)
  wait('the buffer outlived the game', function()
    return not vim.api.nvim_buf_is_valid(buf)
  end)
  vim.wait(20)
end

-- tell is what the next fake game does, its last run's records gone
local function tell(env)
  said = {}
  vim.fn.delete(dir .. '/args')
  vim.fn.delete(dir .. '/pid')
  for _, name in ipairs({ 'VIF_TEST_STATUS', 'VIF_TEST_PRINT', 'VIF_TEST_STAY' }) do
    vim.env[name] = (env or {})[name]
  end
end

-- start runs :Vif against the fake game and returns its buffer
local function start(opts, args, env)
  tell(env)
  require('vif').setup(vim.tbl_extend('keep', opts or {}, { bin = root .. '/tests/vif' }))
  vim.cmd('Vif ' .. (args or ''))
  local buf = vim.api.nvim_get_current_buf()
  assert(vim.bo[buf].buftype == 'terminal', 'no terminal buffer was opened')
  return buf
end

-- play is a game run to its end
local function play(opts, args, env)
  gone(start(opts, args, env))
end

local tests = {
  {
    'the command passes its arguments after the default ones',
    function()
      play({ args = { '-mute' } }, '-s td -join=vifs://host:7777/game')
      same(vim.list_slice(recorded('args'), 3), { '-mute', '-s', 'td', '-join=vifs://host:7777/game' })
    end,
  },
  {
    'the game is told true color exactly when termguicolors is on',
    function()
      for _, on in ipairs({ true, false }) do
        vim.o.termguicolors = on
        play()
        same(recorded('args'), { '-color', on and 'true' or '256' })
      end
    end,
  },
  {
    'a game asked for as Neovim starts opens once it has started',
    function()
      tell()
      local setup = ("lua require('vif').setup({ bin = '%s/tests/vif' })"):format(root)
      local argv = { vim.v.progpath, '--headless', '-u', 'NONE', '--cmd', 'set rtp^=' .. root }
      vim.list_extend(argv, { '-c', 'runtime plugin/vif.lua', '-c', setup, '-c', 'Vif', '-c', 'set termguicolors' })
      local child = vim.system(argv)
      local started = vim.wait(5000, function()
        return vim.fn.filereadable(dir .. '/pid') == 1
      end)
      child:kill('sigterm')
      assert(started, 'the game never started')
      same(recorded('args'), { '-color', 'true' })
    end,
  },
  {
    'the window closes on exit',
    function()
      for _, layout in ipairs({ 'float', 'tab' }) do
        local wins, tabs = #vim.api.nvim_list_wins(), #vim.api.nvim_list_tabpages()
        play({ layout = layout })
        same({ #vim.api.nvim_list_wins(), #vim.api.nvim_list_tabpages() }, { wins, tabs })
        same(vim.api.nvim_get_mode().mode, 'n')
      end
    end,
  },
  {
    'the game ends with its window',
    function()
      for _, layout in ipairs({ 'float', 'tab' }) do
        local buf = start({ layout = layout }, nil, { VIF_TEST_STAY = '30' })
        wait('the game never started', function()
          return vim.fn.filereadable(dir .. '/pid') == 1
        end)
        local pid = tonumber(recorded('pid')[1])
        vim.cmd.quit()
        wait('the game outlived its window', function()
          return vim.uv.kill(pid, 0) ~= 0
        end)
        gone(buf)
        same(said, {})
      end
    end,
  },
  {
    "a non-zero exit's reason is shown",
    function()
      local reason = 'join host:7777: ' .. ('nothing is listening there '):rep(8) .. 'is the host running?'
      -- A main loop held up as the game goes lets Neovim 0.11 write its own exit row first
      local held = vim.api.nvim_create_autocmd('TermClose', {
        callback = function()
          vim.wait(60)
        end,
      })
      play(nil, nil, { VIF_TEST_STATUS = '3', VIF_TEST_PRINT = reason })
      vim.api.nvim_del_autocmd(held)
      same(said, { { msg = 'vif: ' .. reason, level = vim.log.levels.ERROR } })
      play(nil, nil, { VIF_TEST_STATUS = '3' })
      same(said, { { msg = 'vif: exited with status 3', level = vim.log.levels.ERROR } })
      play(nil, nil, { VIF_TEST_PRINT = 'logging enabled' })
      same(said, {})
    end,
  },
  {
    'a missing binary is reported',
    function()
      local wins = #vim.api.nvim_list_wins()
      said = {}
      require('vif').setup({ bin = dir .. '/absent' })
      vim.cmd('Vif')
      same(#said, 1)
      assert(said[1].msg:find('go install github.com/lixenwraith/vif/cmd/vif@latest', 1, true), said[1].msg)
      same({ said[1].level, #vim.api.nvim_list_wins() }, { vim.log.levels.ERROR, wins })
    end,
  },
}

local failed = 0
for _, test in ipairs(tests) do
  local ok, err = pcall(test[2])
  failed = failed + (ok and 0 or 1)
  io.write(ok and 'ok    ' or 'FAIL  ', test[1], ok and '' or '\n      ' .. tostring(err), '\n')
end
vim.cmd.cquit({ count = failed })
