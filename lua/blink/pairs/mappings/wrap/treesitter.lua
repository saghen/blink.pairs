local nvim = require('blink.lib.nvim')
local rust = require('blink.pairs.rust')

--- @class blink.pairs.TsWrapState
--- @field bufnr integer
--- @field changedtick integer
--- @field text string Closing delimiter
--- @field row integer
--- @field cols integer[] Columns the closing delimiter cycles through, first is the original column
--- @field idx integer Index into `cols` of the current column

local treesitter = {
  --- @type blink.pairs.TsWrapState?
  state = nil,
}

--- TS node cycling: move closing pair to next/prev treesitter node boundary
--- @param direction 'fwd' | 'rev'
function treesitter.wrap(direction)
  local bufnr = nvim.get_current_buf()
  local changedtick = nvim.buf_get_changedtick(bufnr)

  -- Continue cycling unless the buffer changed since the last move
  local state = treesitter.state
  if not state or state.bufnr ~= bufnr or state.changedtick ~= changedtick then
    state = treesitter.new_state(bufnr)
    if not state then return end
  end

  local idx = state.idx + (direction == 'fwd' and 1 or -1)
  if idx < 1 or idx > #state.cols then return end
  local from, to = state.cols[state.idx], state.cols[idx]

  nvim.buf_set_text(bufnr, state.row, from, state.row, from + #state.text, {})
  nvim.buf_set_text(bufnr, state.row, to, state.row, to, { state.text })
  nvim.win_set_cursor(0, { state.row + 1, to })

  state.idx = idx
  state.changedtick = nvim.buf_get_changedtick(bufnr)
  treesitter.state = state
end

--- Finds the pair surrounding the cursor and the treesitter nodes ending after it on the same line
--- @param bufnr integer
--- @return blink.pairs.TsWrapState?
function treesitter.new_state(bufnr)
  local cursor = nvim.win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  local pair = rust.get_surrounding_match_pair(bufnr, row, col, true)
  if not pair then return end
  local close = pair[2]
  local text = close[2] or close[1]
  if close.line ~= row then return end

  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, col } })
  if not ok then return end

  -- node ends after the closing delimiter, in the columns of the line without it
  local cols, seen = { close.col }, {}
  while node do
    local _, _, end_row, end_col = node:range()
    if end_row == row and end_col > close.col + #text and not seen[end_col] then
      seen[end_col] = true
      table.insert(cols, end_col - #text)
    end
    node = node:parent()
  end
  if #cols == 1 then return end
  table.sort(cols)

  return { bufnr = bufnr, changedtick = nvim.buf_get_changedtick(bufnr), row = row, text = text, cols = cols, idx = 1 }
end

return treesitter
