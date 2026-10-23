local nvim = require('blink.lib.nvim')
local mappings = require('blink.pairs.mappings')
local rust = require('blink.pairs.rust')

--- @class blink.pairs.TsWrapState
--- @field bufnr integer
--- @field changedtick integer
--- @field text string Closing delimiter
--- @field row integer
--- @field cols integer[] Columns the closing delimiter cycles through, first is the original column
--- @field idx integer Index into `cols` of the current column
--- @field cursor [integer, integer] Cursor position after the last move

local treesitter = {
  --- @type blink.pairs.TsWrapState?
  state = nil,
}

--- TS node cycling: move closing pair to next/prev treesitter node boundary
--- @param direction 'fwd' | 'rev'
function treesitter.wrap(direction)
  if not mappings.is_enabled() then return end
  local bufnr = nvim.get_current_buf()
  local changedtick = nvim.buf_get_changedtick(bufnr)
  local cursor = nvim.win_get_cursor(0)

  -- Continue cycling only while editing the same pair at the same cursor position
  local state = treesitter.state
  if
    not state
    or state.bufnr ~= bufnr
    or state.changedtick ~= changedtick
    or not vim.deep_equal(state.cursor, cursor)
  then
    treesitter.state = nil
    state = treesitter.new_state(bufnr)
    if not state then return end
  end

  local idx = state.idx + (direction == 'fwd' and 1 or -1)
  if idx < 1 or idx > #state.cols then return end
  local from, to = state.cols[state.idx], state.cols[idx]

  nvim.buf_set_text(bufnr, state.row, from, state.row, from + #state.text, {})
  vim.cmd('undojoin')
  nvim.buf_set_text(bufnr, state.row, to, state.row, to, { state.text })
  nvim.win_set_cursor(0, { state.row + 1, to })

  state.idx = idx
  state.changedtick = nvim.buf_get_changedtick(bufnr)
  state.cursor = nvim.win_get_cursor(0)
  treesitter.state = state
end

--- Finds the next closing pair and the treesitter nodes ending after it on the same line
--- @param bufnr integer
--- @return blink.pairs.TsWrapState?
function treesitter.new_state(bufnr)
  local cursor = nvim.win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return end
  -- get_node() does not refresh the syntax tree after edits.
  local trees = parser:parse({ row, row + 1 })
  if not trees or not require('blink.pairs.watcher').attach(bufnr) then return end

  local close
  for _, token_type in ipairs({ 0, 1, 2 }) do
    for _, match in ipairs(rust.get_line_matches(bufnr, row, token_type)) do
      if match.col >= col then
        local pair = rust.get_match_pair(bufnr, row, match.col)
        if pair and pair[2].line == row and pair[2].col == match.col then
          if not close or match.col < close.col then close = pair[2] end
        end
      end
    end
  end
  if not close then return end
  local text = close[2] or close[1]
  local close_end = close.col + #text

  -- Include following sibling nodes, which may be under ERROR while typing good()a.
  -- Store columns in the line with the closing delimiter removed.
  local cols, seen = { close.col }, {}
  local function collect(node)
    local start_row, _, end_row, end_col = node:range()
    if start_row > row or end_row < row or (end_row == row and end_col <= close_end) then return end
    if node:type():find('comment') then return end
    if node:named() and end_row == row and end_col > close_end and not seen[end_col] then
      seen[end_col] = true
      table.insert(cols, end_col - #text)
    end
    for child in node:iter_children() do
      collect(child)
    end
  end
  for _, tree in ipairs(trees) do
    collect(tree:root())
  end
  if #cols == 1 then return end
  table.sort(cols)

  return {
    bufnr = bufnr,
    changedtick = nvim.buf_get_changedtick(bufnr),
    row = row,
    text = text,
    cols = cols,
    idx = 1,
    cursor = cursor,
  }
end

return treesitter
