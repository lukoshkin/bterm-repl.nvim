local M = {}
local utils = require 'bottom-term-repl.utils'
local repl = require 'bottom-term-repl.core'
local api = vim.api


function M.setup(conf)
  conf = vim.tbl_deep_extend("keep", conf or {}, utils.default)
  conf.valid_buffers = vim.tbl_keys(conf.delimiters)

  conf.pats = {}
  conf.pats = vim.tbl_map(function(delim_list)
    return table.concat(vim.tbl_map(function(delim)
      return '^\\s*' .. delim .. '.*'
    end, delim_list), '\\|')
  end, conf.delimiters)

  conf.hl_group_prefix = "BTermReplDelim"
  repl.conf = conf -- it is important to pass configs before setting mappings
  vim.keymap.set('n', conf.keys.ipy_launch, repl.start_ipython_session)
  vim.keymap.set('n', conf.keys.select_session, repl.select_session)
  vim.keymap.set('n', conf.keys.restart, repl.restart_interpreter)
  vim.keymap.set('n', conf.keys.close_xwins, repl.close_xwins)

  vim.keymap.set('n', conf.keys.run_line, repl.copy_line_and_run)
  vim.keymap.set('n', conf.keys.run_cell, repl.run_cell)
  vim.keymap.set('n', conf.keys.run_and_jump, repl.run_and_jump)

  vim.keymap.set('n', conf.keys.next_cell, repl.jump_to_next_cell())
  vim.keymap.set('n', conf.keys.prev_cell, repl.jump_to_next_cell('b'))
  vim.keymap.set('n', conf.keys.toggle_separator, repl.toggle_separator)
  vim.keymap.set('n', conf.keys.clear, repl.clear_console)

  local aug_btrd = api.nvim_create_augroup(conf.hl_group_prefix, {})
  api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter'}, {
      callback = require 'bottom-term-repl.colors'.match_delims,
      group = aug_btrd
  })
end

return M
