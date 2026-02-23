local mappings = require('blink.pairs.mappings')

local M = {}

local start_pos

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
end

--- @param definitions blink.pairs.WrapDefinitions
M.register = function(definitions)
  for key, pair in pairs(definitions) do
    if pair == 'in_pair' then
      M.register_in_pair(key)
    else
      M.register_pair(key, pair)
    end
  end
end

--- @param definitions blink.pairs.WrapDefinitions
M.unregister = function(definitions)
  for key, _ in pairs(definitions) do
    vim.keymap.del('i', key)
  end
end

--- @param key string
M.register_in_pair = function(key)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    start_pos = vim.api.nvim_win_get_cursor(0)
    start_pos[2] = start_pos[2] + 1
    vim.o.operatorfunc = 'v:lua.blink_pairs_wrap'
    return '<C-g>u<Right><C-o>g@'
  end, { expr = true, desc = 'Wrap parenthesis after cursor via motion' })
end

--- @param key string
--- @param pair string
M.register_pair = function(key, pair)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    start_pos = vim.api.nvim_win_get_cursor(0)
    start_pos[2] = start_pos[2] + #pair
    vim.o.operatorfunc = 'v:lua.blink_pairs_wrap'
    return pair .. '<C-o>g@'
  end, { expr = true, desc = 'Insert () and wrap via motion' })
end

return M
