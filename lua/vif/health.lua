local M = {}

function M.check()
  local health = vim.health
  health.start('vif.nvim')

  local nvim = ('Neovim %s: vif.nvim needs 0.11 or newer'):format(tostring(vim.version()))
  if vim.fn.has('nvim-0.11') == 1 then
    health.ok(nvim)
  else
    health.error(nvim)
  end

  local bin, missing = require('vif').binary()
  if not bin then
    health.error(missing)
  else
    local version = vim.trim(vim.fn.system({ bin, '-version' }))
    if vim.v.shell_error == 0 then
      health.ok(bin .. ': ' .. version)
    else
      health.error(bin .. ' -version failed: ' .. version)
    end
  end

  if vim.o.termguicolors then
    health.ok("'termguicolors' is on: the game draws in true color")
  else
    health.info("'termguicolors' is off: the game draws in 256 colors")
  end
end

return M
