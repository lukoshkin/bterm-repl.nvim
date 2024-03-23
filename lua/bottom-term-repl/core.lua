local bt = require "bottom-term.core"
local bt_utils = require "bottom-term.utils"
local utils = require "bottom-term-repl.utils"

local api = vim.api
local fn = vim.fn

local M = {}
M._current_sep_id = 1

function M.jump_to_next_cell(search_opts)
  search_opts = search_opts or ""
  return function()
    local ft = utils.get_ft_or_compare()
    if not vim.tbl_contains(M.conf.valid_buffers, ft) then
      return
    end

    if
      fn.search(M.conf.pats[ft], search_opts .. "W") == 0
      and search_opts == "b"
    then
      api.nvim_win_set_cursor(0, { 1, 0 })
    end
  end
end

function M.copy_line_and_run()
  local line = api.nvim_get_current_line()
  bt.execute(line)
end

function M.copy_cell(pat, sep)
  if sep == nil then
    sep = "\n"
  end
  local top = fn.search(pat, "bcnW") -- either <some> or zero (beg)
  local bot = fn.search(pat, "nW") - 1 -- either <some> - 1 or -1 (end)
  local lines = api.nvim_buf_get_lines(0, top, bot, false)
  lines = vim.tbl_filter(function(line)
    return line:match "^%s*$" == nil
  end, lines)
  return table.concat(lines, sep)
end

local function round_trip(fn_to_call)
  --- In the previous patch, it was also used in `ipython_run_cell`.
  local bak_wid = api.nvim_get_current_win()
  api.nvim_set_current_win(fn.bufwinid(vim.t.bottom_term_name))

  fn_to_call()

  vim.defer_fn(function()
    api.nvim_set_current_win(bak_wid)
  end, 10) -- one can experiment with the delay value:
  --- even 5ms seems to be enough.
end

function M.clear_console()
  if not bt.is_visible() then
    return
  end

  local tnr = api.nvim_get_current_tabpage()
  local cmd = "clear"

  if bt._ephemeral[tnr].ss_exists and bt._ephemeral[tnr].launched_by "lua" then
    cmd = 'os.execute("clear")'
  end

  round_trip(function()
    bt.execute(cmd)
  end)
end

function M.ipython_run_cell(pat)
  if M._current_sep_id ~= 1 then
    local sep = M.conf.line_separators[M._current_sep_id]
    --- Because of '^C' I can't add a condition in `run_cell` readily,
    --- so that this special case would go into the `else` branch.
    --- '^C' is to discard any input
    bt.execute("" .. M.copy_cell(pat, sep) .. sep)
    --- Sep in this case should be '', where:
    --- '^O' - add a new line below,
    --- '^A' - go to the current line beginning,
    --- '^N' - go to the line below.
    --- Otherwise, the tab indentation will be broken.
    return
  end

  fn.setreg("l", fn.getreg "+")
  fn.setreg("+", M.copy_cell(pat))
  bt.execute "%paste -q"

  --- Restore the original content of the clipboard in a number of ms specified
  --- by `M.clipboard_occupation_time`. 500ms should be enough to paste the new
  --- one to IPython's cmdline. But it is bad if a user tries to copy sth
  --- during this short window.
  vim.defer_fn(function()
    fn.setreg("+", fn.getreg "l")
  end, M.conf.clipboard_occupation_time)
end

function M.run_cell()
  local tnr = api.nvim_get_current_tabpage()
  if
    not bt.is_visible()
    or not bt._ephemeral[tnr].ss_exists
    or bt_utils.is_buftype_terminal()
  then
    --- Quit early if one of the following is true:
    --- `bottom_term` is not visible;
    --- `start_repl_session` was never called;
    --- "code" is sent from terminal buffer.
    return
  end

  local ft = utils.get_ft_or_compare()
  if bt._ephemeral[tnr].launched_by "ipython" then
    --- Here we actually allow also to run python code from
    --- non-python buffer (by passing filetype of the current buffer
    --- and not just hardcoding it as 'python').
    M.ipython_run_cell(M.conf.pats[ft] or M.conf.pats.python)
  else -- run cell line by line
    local sep = M.conf.line_separators[M._current_sep_id]
    bt.execute(M.copy_cell(M.conf.pats[ft], sep))
  end
end

function M.run_and_jump()
  --- NOTE: not sure but may help when calling it multiple times
  --- within a short time interval.
  vim.schedule(function()
    M.run_cell()
    M.jump_to_next_cell()()
  end)
end

function M.toggle_separator(forward, backward)
  forward = forward or 1
  assert(forward == 1, "`forward` (the first arg) should always be 1")

  backward = backward or 0
  assert(
    vim.tbl_contains({ 0, 2 }, backward),
    "`backward` (the second arg) can be either 0 or 2"
  )

  if not bt._ephemeral[api.nvim_get_current_tabpage()] then
    return
  end

  M._current_sep_id = (M._current_sep_id - backward) % #M.conf.line_separators
    + forward

  local sep = M.conf.line_separators[M._current_sep_id] or "\n"
  if M._current_sep_id ~= 1 and sep == "\n" then
    sep = sep .. " (Vim -> Docker:IPython)"
  end

  local log_lvl = "info"
  utils.notify(
    "Line separator has been changed to "
      .. "'"
      .. fn.substitute(sep, "\n", "<NL>", "g")
      .. "'",
    log_lvl
  )
end

function M.restart_interpreter()
  local tnr = api.nvim_get_current_tabpage()
  local was_horizontal = vim.t.bottom_term_horizontal
  local session_attrs = bt._ephemeral[tnr]

  bt.terminate()
  bt.bottom_term_new(session_attrs.start_cmd)
  bt._ephemeral[tnr] = session_attrs

  if not was_horizontal and vim.t.bottom_term_horizontal then
    bt.reverse_orientation()
  end
end

function M.close_xwins()
  local tnr = api.nvim_get_current_tabpage()

  if
    bt._ephemeral[tnr] ~= nil
    and bt._ephemeral[tnr].ss_exists
    and bt._ephemeral[tnr].launched_by "ipython"
  then
    bt.execute 'try: plt.close("all")\nexcept: pass'
  end
end

local function start_repl_session(cmd)
  local status_ok = true
  if vim.t.bottom_term_name ~= nil then
    vim.ui.input({
      prompt = "Switching to a new terminal session will result in "
        .. "closing the current one. Do you want to proceed? [y/n] ",
      default = "y",
    }, function(user)
      if user ~= nil and user:lower() == "y" then
        bt.terminate()
      else
        status_ok = false
      end
    end)
  end

  if not status_ok then
    return
  end

  bt.bottom_term_new(cmd)
  bt.reverse_orientation()
  local tnr = api.nvim_get_current_tabpage()

  bt._ephemeral[tnr].start_cmd = cmd
  --- We could get rid of `ss_exists` and use `start_cmd ~= nil` instead.
  bt._ephemeral[tnr].ss_exists = true
  bt._ephemeral[tnr].launched_by = function(val)
    return cmd:match("%s*" .. val .. "%s*") ~= nil
  end
end

function M.select_session()
  local caller_wid = api.nvim_get_current_win()
  local shell = vim.o.shell or vim.env.SHELL or ""
  shell = shell:match "^.+/(.+)$" or "bash"

  vim.ui.input(
    { prompt = "Select interpreter [" .. shell .. "] " },
    function(cmd)
      if cmd ~= nil then
        start_repl_session(cmd)
      end
    end
  )
  if api.nvim_win_is_valid(caller_wid) then
    api.nvim_set_current_win(caller_wid)
  end
  vim.cmd "stopinsert"
end

local function call_from_scratch_checks()
  local check = "command -v ipython | grep -q 'ipython'"

  if not utils.has_package(check) then
    utils.notify("IPython is not installed! Aborting..", "error")
    return ""
  end

  check = "pip3 --disable-pip-version-check list 2>&1"
  check = check .. [[ | grep -qP 'matplotlib(?!-inline)' ]]

  local cmd = "ipython"
  if utils.has_package(check) then
    cmd = cmd .. " --matplotlib"
  else
    utils.notify("Matplotlib is not installed.", "warning")
  end

  return cmd
end

function M.start_ipython_session()
  local tnr = api.nvim_get_current_tabpage()
  local remind_about_toggle = false

  if
    bt._ephemeral[tnr]
    and bt._ephemeral[tnr].ss_exists
    and bt._ephemeral[tnr].ips_exists
  then
    remind_about_toggle = true
  end

  --- Should be before `start_repl_session` call.
  local caller_wid = api.nvim_get_current_win()
  local cmd

  if bt._ephemeral[tnr] == nil then
    cmd = call_from_scratch_checks()
  else
    cmd = "command -v ipython && ipython || { echo;"
    cmd = cmd .. " echo Either IPython is not installed or"
    cmd = cmd .. " there are problems with running it; exit; }"
  end

  if cmd == "" then
    return
  end

  start_repl_session(cmd)
  if remind_about_toggle then
    utils.notify("To hide/unfold window, use " .. bt.keys.toggle, "info")
  end

  if api.nvim_win_is_valid(caller_wid) then
    api.nvim_set_current_win(caller_wid)
  end

  vim.cmd "stopinsert"
  bt._ephemeral[tnr].ips_exists = true
  bt.opts.focus_on_caller = true
  bt.opts.insert_on_switch = false
end

return M
