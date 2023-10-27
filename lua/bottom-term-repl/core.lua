local bt = require'bottom-term.core'
local utils = require'bottom-term-repl.utils'

local api = vim.api
local fn = vim.fn
local M = {}


function M.jump_to_next_cell(search_opts)
  search_opts = search_opts or ''
  return function()
    local ft = utils.get_ft_or_compare()
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


function M.copy_cell(pat, sep)
  if sep == nil then sep = '\n' end
  local top = fn.search(pat, 'bcnW')     -- either <some> or zero (beg)
  local bot = fn.search(pat, 'nW') - 1 -- either <some> - 1 or -1 (end)
  return table.concat(api.nvim_buf_get_lines(0, top, bot, false), sep)
end


function M.clear_console()
  if not bt.is_visible() then
    return
  end

  local tnr = api.nvim_get_current_tabpage()
  if bt._ephemeral[tnr].ss_exists
    and bt._ephemeral[tnr].launched_by 'lua' then
    bt.execute 'os.execute("clear")'
  else
    bt.execute 'clear'
  end
end


function M.ipython_run_cell(pat)
  fn.setreg('l', fn.getreg('+'))
  fn.setreg('+', M.copy_cell(pat))
  bt.execute '%paste -q'

  --- Restore the original content of the clipboard in a number of ms specified
  --- by `M.clipboard_occupation_time`. 500ms should be enough to paste the new
  --- one to IPython's cmdline. But it is bad if a user tries to copy sth
  --- during this short window.
  vim.defer_fn(function()
    fn.setreg('+', fn.getreg('l'))
  end, M.conf.clipboard_occupation_time)
end


function M.run_cell()
  local tnr = api.nvim_get_current_tabpage()
  if not bt.is_visible() or not bt._ephemeral[tnr].ss_exists then
    --- Either bottom term is not visible
    --- or `start_repl_session` was never called.
    return
  end

  local ft = utils.get_ft_or_compare()
  if bt._ephemeral[tnr].launched_by 'ipython' then
    --- Here we actually allow also to run python code from
    --- non-python buffer (by passing filetype of the current buffer).
    M.ipython_run_cell(M.conf.pats[ft] or M.conf.pats.python)
  else -- run cell line by line
    bt.execute(M.copy_cell(M.conf.pats[ft], M._current_sep))
  end
end


function M.run_and_jump()
  --- NOTE: not sure but may help when calling it two times
  --- within a short time interval.
  vim.schedule(function()
    M.run_cell()
    M.jump_to_next_cell()()
  end)
end


function M.toggle_separator()
  if M._current_sep == nil then
    M._current_sep = M.conf.second_separator
  else
    M._current_sep = nil
  end

  local log_lvl = 'info'
  local suffix = ''

  local tnr = api.nvim_get_current_tabpage()
  if bt._ephemeral[tnr].launched_by 'ipython' then
    log_lvl = 'warning'
    suffix = "\n However, it has no effect on IPython REPL"
  end

  utils.notify(
    'Line separator has been changed to '
    .. "'" .. (M._current_sep or '\\n') .. "'" .. suffix, log_lvl)
end


function M.restart_interpreter()
  local tnr = api.nvim_get_current_tabpage()

  if not bt._ephemeral[tnr].has_parent then
    utils.notify('There is no parent process!\n Calling `restart` fn '
      .. 'in this case\n would lead to closing the terminal window')
    return
  end

  local exit
  if bt._ephemeral[tnr].launched_by 'lua' then
    exit = 'os.exit()'
  else
    exit = 'exit'
  end

  bt.execute(exit)
  --- Repeat the launch command after a small delay.
  vim.defer_fn(function () bt.execute '!!' end, 50)
end


function M.close_xwins()
  local tnr = api.nvim_get_current_tabpage()

  if bt._ephemeral[tnr] ~= nil
    and bt._ephemeral[tnr].ss_exists
    and bt._ephemeral[tnr].launched_by 'ipython' then
    bt.execute 'try: plt.close("all")\nexcept: pass'
  end
end


local function start_repl_session (cmd)
  if not bt.is_visible() then
    bt.toggle()
  end
  bt.execute(cmd)

  if vim.t.bottom_term_horizontal then
    bt.reverse_orientation()
  end

  local tnr = api.nvim_get_current_tabpage()

  bt._ephemeral[tnr].ss_exists = true
  bt._ephemeral[tnr].has_parent = cmd ~= '' and cmd:match '%s*exec%s' == nil
  bt._ephemeral[tnr].launched_by = function (val)
    return cmd:match('%s*' .. val .. '%s*') ~= nil
  end
end


function M.select_session ()
  local tnr = api.nvim_get_current_tabpage()
  if bt._ephemeral[tnr] and bt._ephemeral[tnr].ss_exists then
    if bt._ephemeral[tnr].ips_exists then
      bt.terminate()
    else
      bt.toggle()
      return
    end
  end

  local caller_wid = api.nvim_get_current_win()
  local shell = vim.o.shell or vim.env.SHELL or ''
  shell = shell:match('^.+/(.+)$') or 'bash'

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
  local tnr = api.nvim_get_current_tabpage()

  if bt._ephemeral[tnr] and bt._ephemeral[tnr].ss_exists then
    if bt._ephemeral[tnr].ips_exists then
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

  bt._ephemeral[tnr].ips_exists = true
  bt.opts.focus_on_caller = true
end

return M
