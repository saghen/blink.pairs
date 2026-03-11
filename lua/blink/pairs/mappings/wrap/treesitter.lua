local mappings = require('blink.pairs.mappings')
local rust = require('blink.pairs.rust')

--- @class blink.pairs.TsWrapState
--- @field bufnr integer
--- @field original_close_row integer
--- @field original_close_col integer
--- @field close_char string
--- @field targets { end_row: integer, end_col: integer }[]
--- @field target_idx integer
--- @field changedtick integer

local treesitter = {
  --- @type blink.pairs.TsWrapState?
  state = nil,
}

--- TS node cycling: move closing pair to next/prev treesitter node boundary
--- @param direction 'fwd' | 'rev'
function treesitter.wrap(direction)
  if not mappings.is_enabled() then return end

  local bufnr = vim.api.nvim_get_current_buf()
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)

  -- Fast path: continue cycling without Rust parser or treesitter lookups
  if treesitter.state and treesitter.state.bufnr == bufnr and treesitter.state.changedtick == changedtick then
    return treesitter.wrap_move(direction, treesitter.state)
  end

  -- Slow path: initialize new cycle
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]

  local pair = rust.get_surrounding_match_pair(bufnr, row, col)
  if not pair or #pair < 2 then return end

  local close_match = pair[2]
  local close_char = close_match[2] or close_match[1]
  local close_end = close_match.col + #close_char

  local nodes = treesitter.get_wrap_nodes(bufnr, row, col)
  if not nodes then return end

  local targets = {}
  local tn = 0
  for i = 1, #nodes do
    local node = nodes[i]
    if node.end_row == close_match.line and node.end_col > close_end then
      tn = tn + 1
      targets[tn] = node
    end
  end

  if tn == 0 then return end

  treesitter.state = {
    bufnr = bufnr,
    original_close_row = close_match.line,
    original_close_col = close_match.col,
    close_char = close_char,
    targets = targets,
    target_idx = 0,
    changedtick = changedtick,
  }

  treesitter.wrap_move(direction, treesitter.state)
end

--- Get TS nodes from position upward, deduped and sorted by end position
--- @return { end_row: integer, end_col: integer }[]?
function treesitter.get_wrap_nodes(bufnr, row, col)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, col } })
  if not ok or not node then return nil end

  local nodes = {}
  local n = 0
  local seen = {}
  while node do
    local _, _, er, ec = node:range()
    local key = er * 1000000 + ec
    if not seen[key] then
      seen[key] = true
      n = n + 1
      nodes[n] = { end_row = er, end_col = ec }
    end
    node = node:parent()
  end

  table.sort(nodes, function(a, b)
    if a.end_row ~= b.end_row then return a.end_row < b.end_row end
    return a.end_col < b.end_col
  end)

  return nodes
end

--- @param direction 'fwd' | 'rev'
--- @param ts_state blink.pairs.TsWrapState
function treesitter.wrap_move(direction, ts_state)
  local new_idx
  if direction == 'fwd' then
    new_idx = ts_state.target_idx + 1
    if new_idx > #ts_state.targets then return end
  else
    new_idx = ts_state.target_idx - 1
    if new_idx < 0 then return end
  end

  local cur_row, cur_col
  if ts_state.target_idx == 0 then
    cur_row = ts_state.original_close_row
    cur_col = ts_state.original_close_col
  else
    local t = ts_state.targets[ts_state.target_idx]
    cur_row = t.end_row
    cur_col = t.end_col - #ts_state.close_char
  end

  local tgt_row, tgt_col
  if new_idx == 0 then
    tgt_row = ts_state.original_close_row
    tgt_col = ts_state.original_close_col
  else
    local t = ts_state.targets[new_idx]
    tgt_row = t.end_row
    tgt_col = t.end_col
  end

  local bufnr = ts_state.bufnr
  local cc = ts_state.close_char

  vim.api.nvim_buf_set_text(bufnr, cur_row, cur_col, cur_row, cur_col + #cc, { '' })

  if tgt_row == cur_row and tgt_col > cur_col then tgt_col = tgt_col - #cc end

  vim.api.nvim_buf_set_text(bufnr, tgt_row, tgt_col, tgt_row, tgt_col, { cc })

  ts_state.target_idx = new_idx
  ts_state.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
end

return treesitter
