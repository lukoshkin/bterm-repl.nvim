local M = {}

M.default = {
  delimiters = {
    python = { '#%%', '# %%', '# In\\[\\(\\d\\+\\| \\)\\]:' },
    lua = { '--#' },
    sh = { '#%%' },
  },
  keys = {
    clear = '<Space>l',
    next_cell = '<Space>jn',
    prev_cell = '<Space>jp',
    restart = '<Space>00',
    close_xwins = '<Space>x',  -- not implemented yet
    run_line = '<C-c><C-c>',
    run_cell = '<CR>',
    run_and_jump = '<Space><CR>',
    select_session = '<Leader>ss',
    ipy_launch = '<Space>ip',
  },
  colors = {
    python = { bold = true, bg = '#306998', fg = '#FFD43B' },
    lua = { bold = true, bg = '#C5C5E1', fg = '#6B6BB3' },
    sh = { bold = true, bg = '#293137', fg = '#4EAA25' },
  }
}


function M.notify(msg, log_lvl_key)
  local log_lvl_vals = { warning = vim.log.levels.WARN, error = 'error' }
  vim.notify(
    ' ' .. msg,
    log_lvl_vals[log_lvl_key],
    { title = 'BottomTerm-Repl' }
  )
end

function shellcmd_capture(cmd)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()

  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

function M.has_package(check_cmd)
  local cmd = check_cmd .. '; echo $?'
  local code = shellcmd_capture(cmd)
  return tonumber(code) == 0
end

return M
