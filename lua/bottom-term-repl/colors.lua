local repl = require "bottom-term-repl.core"

local api = vim.api
local fn = vim.fn
local M = {}

local function is_in_match_groups(name)
  local match_groups = vim.tbl_map(function(l)
    return l.group
  end, fn.getmatches())
  return vim.tbl_contains(match_groups, name)
end

local function clear_delim_match()
  if not vim.w.repl_delim_match then
    return
  end

  for hl_gn, mid in pairs(vim.w.repl_delim_match) do
    if is_in_match_groups(hl_gn) then
      fn.matchdelete(mid)
      vim.w.repl_delim_match = nil
    end
  end
end

function M.match_delims()
  local ft = api.nvim_buf_get_option(0, "filetype")

  if vim.tbl_contains(repl.conf.valid_buffers, ft) then
    if ft ~= M.prev_ft then
      clear_delim_match()
    end

    if vim.w.repl_delim_match == nil then
      local hl_gn = repl.conf.hl_group_prefix .. ft
      local mid = fn.matchadd(hl_gn, repl.conf.pats[ft])
      api.nvim_set_hl(0, hl_gn, repl.conf.colors[ft])
      vim.w.repl_delim_match = { hl_gn = mid }
    end

    M.prev_ft = ft
  else
    clear_delim_match()
  end
end

return M
