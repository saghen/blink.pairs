local motions = {}

--- @type [integer, integer]
local cursor
--- @type [integer, integer]
local start_pos
--- @type blink.pairs.WrapOpts?
local wrap_opts

--- @param start_pos_ [integer, integer]
--- @param wrap_opts_? blink.pairs.WrapOpts
--- @param cursor_? [integer, integer]
function motions.set_operator_wrap(start_pos_, wrap_opts_, cursor_)
  cursor = cursor_ or vim.api.nvim_win_get_cursor(0)
  cursor[2] = cursor[2] - 1

  start_pos = start_pos_
  wrap_opts = wrap_opts_

  vim.o.operatorfunc = 'v:lua.blink_pairs_wrap'
end

--- @param start_pos_ [integer, integer]
--- @param wrap_opts_? blink.pairs.WrapOpts
function motions.set_operator_wrap_reverse(start_pos_, wrap_opts_)
  cursor = vim.api.nvim_win_get_cursor(0)
  start_pos = start_pos_
  wrap_opts = wrap_opts_

  vim.o.operatorfunc = 'v:lua.blink_pairs_wrap_reverse'
end

-- Must be a _G global because vim's operatorfunc requires v:lua.<name>
-- Forward wrap operator: moves pair character at start_pos to motion end
_G.blink_pairs_wrap = function()
  local motion_start_pos = vim.api.nvim_buf_get_mark(0, '[') -- start of operated region
  local motion_end_pos = vim.api.nvim_buf_get_mark(0, ']') -- end of operated region
  if motion_start_pos[1] == 0 or motion_end_pos[1] == 0 then return end -- not set, didn't complete motion

  local new_pos
  if cursor[1] == motion_end_pos[1] and cursor[2] == motion_end_pos[2] then
    -- motion is backward
    new_pos = motion_start_pos
    new_pos[2] = new_pos[2] - 1
  else
    -- motion is forward
    new_pos = motion_end_pos
  end

  -- special case for end of line so that pressing `e` moves the paren to the end of the line
  if
    new_pos[1] == start_pos[1]
    and new_pos[2] == start_pos[2] - 1
    and start_pos[2] + 1 == #vim.api.nvim_buf_get_lines(0, start_pos[1] - 1, start_pos[1], true)[1]
  then
    new_pos[2] = new_pos[2] + 1
  end

  -- get parenthesis and set it to the new position
  local paren = vim.api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2], {})
  vim.api.nvim_buf_set_text(0, new_pos[1] - 1, new_pos[2] + 1, new_pos[1] - 1, new_pos[2] + 1, { paren[1] })

  -- clear parenthesis at the original position
  if start_pos[1] == new_pos[1] and start_pos[2] > new_pos[2] then
    -- compensate for the new position being 1 character to the right of the original position
    -- since we inserted the character at the new position
    start_pos[2] = start_pos[2] + 1
    new_pos[2] = new_pos[2] + 1
  end
  vim.api.nvim_buf_set_text(0, start_pos[1] - 1, start_pos[2] - 1, start_pos[1] - 1, start_pos[2], { '' })

  if wrap_opts and wrap_opts.move_cursor == false then
    vim.api.nvim_win_set_cursor(0, { start_pos[1], start_pos[2] - 2 })
  else
    vim.api.nvim_win_set_cursor(0, new_pos)
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
