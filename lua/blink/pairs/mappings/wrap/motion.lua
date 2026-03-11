local motions = {}

--- @type [integer, integer]
local start_pos
--- @type blink.pairs.WrapOpts?
local wrap_opts

--- @param start_pos_ [integer, integer]
--- @param wrap_opts_? blink.pairs.WrapOpts
function motions.set_operator_wrap(start_pos_, wrap_opts_)
  start_pos = start_pos_
  wrap_opts = wrap_opts_
  vim.o.operatorfunc = 'v:lua.blink_pairs_wrap'
end

--- @param start_pos_ [integer, integer]
--- @param wrap_opts_? blink.pairs.WrapOpts
function motions.set_operator_wrap_reverse(start_pos_, wrap_opts_)
  start_pos = start_pos_
  wrap_opts = wrap_opts_
  vim.o.operatorfunc = 'v:lua.blink_pairs_wrap_reverse'
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

  if wrap_opts and wrap_opts.move_cursor == false then
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

return motions
