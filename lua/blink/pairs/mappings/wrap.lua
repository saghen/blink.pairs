local mappings = require('blink.pairs.mappings')
local rust = require('blink.pairs.rust')

local wrap = {}

local start_pos
local wrap_opts

--- Normalize a wrap definition to table form
--- @param def blink.pairs.WrapValue
--- @return blink.pairs.WrapOpts
local function normalize_def(def)
  if type(def) == 'string' then return { type = def } end
  return def
end

-- Must be a _G global because vim's operatorfunc requires v:lua.<name>
-- Forward wrap operator: moves pair character at start_pos to motion end
_G.blink_pairs_wrap = function()
  local new_pos = vim.api.nvim_buf_get_mark(0, ']') -- get mark set after motion
  if new_pos[1] == 0 then return end -- not set, didn't complete motion

  -- special case for end of line so that pressing `e` moves the paren to the end of the line
  if
    new_pos[1] == start_pos[1]
    and new_pos[2] == start_pos[2] - 1
    and start_pos[2] + 1 == #vim.api.nvim_buf_get_lines(0, start_pos[1] - 1, start_pos[1], true)[1]
  then
    new_pos[2] = new_pos[2] + 1
  end

  local paren = vim.api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2], {})
  vim.api.nvim_buf_set_text(0, new_pos[1] - 1, new_pos[2] + 1, new_pos[1] - 1, new_pos[2] + 1, { paren[1] })
  vim.api.nvim_buf_set_text(0, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2], { '' })

  if wrap_opts and wrap_opts.nocursormove then
    vim.api.nvim_win_set_cursor(0, { start_pos[1], start_pos[2] - 2 })
  end
end

-- Must be a _G global because vim's operatorfunc requires v:lua.<name>
-- Reverse wrap operator: moves pair character at start_pos to motion start
_G.blink_pairs_wrap_reverse = function()
  local new_pos = vim.api.nvim_buf_get_mark(0, '[')
  if new_pos[1] == 0 then return end

  local paren = vim.api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2], {})

  vim.api.nvim_buf_set_text(0, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2], { '' })

  local insert_col = new_pos[2]
  if new_pos[1] == start_pos[1] and insert_col >= start_pos[2] - 1 then insert_col = insert_col - 1 end

  vim.api.nvim_buf_set_text(0, new_pos[1] - 1, insert_col, new_pos[1] - 1, insert_col, { paren[1] })
end

--- @class blink.pairs.TsWrapState
--- @field bufnr integer
--- @field original_close_row integer
--- @field original_close_col integer
--- @field close_char string
--- @field targets { end_row: integer, end_col: integer }[]
--- @field target_idx integer
--- @field changedtick integer

--- @type blink.pairs.TsWrapState?
local ts_state = nil

--- Get TS nodes from position upward, deduped and sorted by end position
--- @return { end_row: integer, end_col: integer }[]?
local function get_wrap_nodes(bufnr, row, col)
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

local function ts_wrap_move(direction)
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

--- TS node cycling: move closing pair to next/prev treesitter node boundary
--- @param direction 'fwd' | 'rev'
function wrap.ts_wrap(direction)
  if not mappings.is_enabled() then return end

  local bufnr = vim.api.nvim_get_current_buf()
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)

  -- Fast path: continue cycling without Rust parser or treesitter lookups
  if ts_state and ts_state.bufnr == bufnr and ts_state.changedtick == changedtick then
    return ts_wrap_move(direction)
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

  local nodes = get_wrap_nodes(bufnr, row, col)
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

  ts_state = {
    bufnr = bufnr,
    original_close_row = close_match.line,
    original_close_col = close_match.col,
    close_char = close_char,
    targets = targets,
    target_idx = 0,
    changedtick = changedtick,
  }

  ts_wrap_move(direction)
end

local registrations = {
  in_pair = function(key, opts) wrap.register_in_pair(key, opts) end,
  reverse_in_pair = function(key, opts) wrap.register_reverse_in_pair(key, opts) end,
  ts_wrap = function(key) wrap.register_ts_wrap(key, 'fwd') end,
  ts_wrap_rev = function(key) wrap.register_ts_wrap(key, 'rev') end,
  normal_in_pair = function(key) wrap.register_normal_in_pair(key) end,
}

--- @param definitions blink.pairs.WrapDefinitions
function wrap.register(definitions)
  for key, def in pairs(definitions) do
    local opts = normalize_def(def)
    local fn = registrations[opts.type]
    if fn then fn(key, opts) else wrap.register_pair(key, opts.type) end
  end
end

local wrap_modes = { normal_in_pair = 'n' }

--- @param definitions blink.pairs.WrapDefinitions
function wrap.unregister(definitions)
  for key, def in pairs(definitions) do
    local opts = normalize_def(def)
    vim.keymap.del(wrap_modes[opts.type] or 'i', key)
  end
end

--- @param key string
--- @param opts? blink.pairs.WrapOpts
function wrap.register_in_pair(key, opts)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    start_pos = vim.api.nvim_win_get_cursor(0)
    start_pos[2] = start_pos[2] + 1
    wrap_opts = opts
    vim.o.operatorfunc = 'v:lua.blink_pairs_wrap'
    return '<C-g>u<Right><C-o>g@'
  end, { expr = true, desc = 'Wrap closing pair forward via motion' })
end

--- @param key string
--- @param opts? blink.pairs.WrapOpts
function wrap.register_reverse_in_pair(key, opts)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local bufnr = vim.api.nvim_get_current_buf()
    local pair = rust.get_surrounding_match_pair(bufnr, cursor[1] - 1, cursor[2])
    if not pair or #pair < 2 then return key end

    local open_match = pair[1]
    start_pos = { open_match.line + 1, open_match.col + 1 } -- 1-indexed
    wrap_opts = opts
    vim.o.operatorfunc = 'v:lua.blink_pairs_wrap_reverse'

    vim.api.nvim_win_set_cursor(0, { open_match.line + 1, open_match.col + #open_match[1] })

    return '<C-g>u<C-o>g@'
  end, { expr = true, desc = 'Wrap opening pair backward via motion' })
end

--- @param key string
--- @param direction 'fwd' | 'rev'
function wrap.register_ts_wrap(key, direction)
  local cmd = "<C-g>u<Cmd>lua require('blink.pairs.mappings.wrap').ts_wrap('" .. direction .. "')<CR>"
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end
    return cmd
  end, { expr = true, desc = 'TS node cycling wrap ' .. direction })
end

--- @param key string
function wrap.register_normal_in_pair(key)
  vim.keymap.set('n', key, function()
    if not mappings.is_enabled() then return key end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local bufnr = vim.api.nvim_get_current_buf()
    local match = rust.get_match_at(bufnr, cursor[1] - 1, cursor[2])
    if not match then return key end

    start_pos = { cursor[1], cursor[2] + 1 }
    wrap_opts = nil
    vim.o.operatorfunc = 'v:lua.blink_pairs_wrap'
    return 'g@'
  end, { expr = true, desc = 'Wrap pair at cursor via motion' })
end

--- @param key string
--- @param pair string
function wrap.register_pair(key, pair)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    start_pos = vim.api.nvim_win_get_cursor(0)
    start_pos[2] = start_pos[2] + #pair
    wrap_opts = nil
    vim.o.operatorfunc = 'v:lua.blink_pairs_wrap'
    return '<C-g>u' .. pair .. '<C-o>g@'
  end, { expr = true, desc = 'Insert () and wrap via motion' })
end

return wrap
