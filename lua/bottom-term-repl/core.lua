local bt = require'bottom-term.core'
local utils = require'bottom-term-repl.utils'

local api = vim.api
local fn = vim.fn
local M = {}


function M.jump_to_next_cell(search_opts)
  search_opts = search_opts or ''
  return function()
    local ft = api.nvim_buf_get_option(0, 'filetype')
    if not vim.tbl_contains(M.conf.valid_buffers, ft) then
      return
    end

    if fn.search(M.conf.pats[ft], search_opts .. 'W') == 0
        and search_opts == 'b' then
      api.nvim_win_set_cursor(0, { 1, 0 })
    end
  end
end


function M.copy_line_and_run()
  local line = api.nvim_get_current_line()
  bt.execute(line)
end


function M.copy_cell(pat)
  local top = fn.search(pat, 'bcnW')     -- either <some> or zero (beg)
  local bot = fn.search(pat, 'nW') - 1 -- either <some> - 1 or -1 (end)
  return table.concat(api.nvim_buf_get_lines(0, top, bot, false), '\n')
end


function M.clear_console()
  if api.nvim_buf_get_option(0, 'filetype') == 'lua' then
    bt.execute('os.execute("clear")')
  else
    bt.execute('clear')
  end
end


function M.ipython_run_cell(pat)
  fn.setreg('l', fn.getreg('+'))
  fn.setreg('+', M.copy_cell(pat))
  bt.execute('%paste -q')

  --- Restore the original content of the clipboard in 500ms.
  --- This should be enough to paste the new one to IPython's cmdline.
  --- But it is bad if a user tries to copy sth during this short window.
  vim.defer_fn(function()
    fn.setreg('+', fn.getreg('l'))
  end, 500)
end


function M.run_cell()
  local ft = api.nvim_buf_get_option(0, 'filetype')
  if not vim.tbl_contains(M.conf.valid_buffers, ft) then
    return
  end

  if ft == 'python' then
    M.ipython_run_cell(M.conf.pats.python)
  else -- run cell line by line
    bt.execute(M.copy_cell(M.conf.pats[ft]))
  end
end


function M.run_and_jump()
  M.run_cell()
  M.jump_to_next_cell()()
end


local function start_repl_session (cmd)
  if not bt.is_visible() then
    bt.toggle()
  end
  bt.execute(cmd)

  if vim.t.bottom_term_horizontal then
    bt.reverse_orientation()
  end

  bt._ephemeral.ss_exists = true
end


function M.select_session ()
  if bt._ephemeral and bt._ephemeral.ss_exists then
    if bt._ephemeral.ips_exists then
      bt.terminate()
    else
      bt.toggle()
      return
    end
  end

  local shell = vim.env.SHELL:match('^.+/(.+)$')
  local caller_wid = api.nvim_get_current_win()

  vim.ui.input(
    { prompt = 'Select interpreter [' .. shell .. '] ' },
    function(cmd)
      if cmd ~= nil then
        start_repl_session(cmd)
      end
    end
  )
  api.nvim_set_current_win(caller_wid)
  vim.cmd 'stopinsert'
end


function M.start_ipython_session ()
  if bt._ephemeral and bt._ephemeral.ss_exists then
    if bt._ephemeral.ips_exists then
      bt.toggle()
      return
    else
      bt.terminate()
    end
  end

  local caller_wid = api.nvim_get_current_win()
  local check = "command -v ipython | grep -q 'ipython'"

  if not utils.has_package(check) then
    utils.notify('IPython is not installed! Aborting..', 'error')
    return
  end

  check = 'pip3 --disable-pip-version-check list 2>&1'
  check = check .. [[ | grep -qP 'matplotlib(?!-inline)' ]]

  local cmd = 'ipython'
  if utils.has_package(check) then
    cmd = cmd .. ' --matplotlib'
  else
    utils.notify('Matplotlib is not installed.', 'warning')
  end

  start_repl_session(cmd)
  api.nvim_set_current_win(caller_wid)
  vim.cmd 'stopinsert'

  bt._ephemeral.ips_exists = true
  bt.opts.focus_on_caller = true
end

return M
