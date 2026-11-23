vim.api.nvim_create_user_command('Vif', function(cmd)
  require('vif').open(cmd.fargs)
end, { nargs = '*', desc = 'Play vif in a terminal buffer' })
