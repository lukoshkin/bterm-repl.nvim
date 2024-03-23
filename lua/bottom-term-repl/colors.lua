local repl = require "bottom-term-repl.core"
local hl_gn = repl.conf.hl_group_prefix

local api = vim.api
local fn = vim.fn
local M = {}

local function clear_delim_match()
  if vim.w.repl_delim_match then
    fn.matchdelete(vim.w.repl_delim_match)
    vim.w.repl_delim_match = nil
  end
end

function M.match_delims()
  local ft = api.nvim_buf_get_option(0, "filetype")

  if vim.tbl_contains(repl.conf.valid_buffers, ft) then
    if ft ~= M.prev_ft then
      clear_delim_match()
    end

    if vim.w.repl_delim_match == nil then
      vim.w.repl_delim_match = fn.matchadd(hl_gn .. ft, repl.conf.pats[ft])
      api.nvim_set_hl(0, hl_gn .. ft, repl.conf.colors[ft])
    end

    M.prev_ft = ft
  else
    clear_delim_match()
  end
end

return M
