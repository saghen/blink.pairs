local rust = require('blink.pairs.rust')

local motions = {}

--- @type [integer, integer]
local cursor
--- @type blink.pairs.WrapType?
local wrap_type
--- @type 'forward' | 'backward' | nil
local direction

--- @param pos [integer, integer]
--- @param col_offset? integer
--- @return blink.pairs.MatchWithLine[]?
function motions.get_pair_at(pos, col_offset)
  local bufnr = vim.api.nvim_get_current_buf()
  return rust.get_surrounding_match_pair(bufnr, pos[1] - 1, math.max(pos[2] + (col_offset or 0), 0))
end

--- Perform setup for the wrap operator, getting the cursor position, storing options
--- and clearing state for dot-repeat
--- @param type blink.pairs.WrapType
function motions.set_operator_wrap(type)
  cursor = vim.api.nvim_win_get_cursor(0)
  cursor[2] = math.max(0, cursor[2] - 1)
  wrap_type = type
  direction = nil

  vim.o.operatorfunc = 'v:lua.blink_pairs_wrap'
end

-- Must be a _G global because vim's operatorfunc requires v:lua.<name>
-- Forward wrap operator: moves pair character at start_pos to motion end
_G.blink_pairs_wrap = function()
  -- called without calling `motions.set_operator_wrap` first
  if not wrap_type or not cursor then return end

  local motion_start_pos = vim.api.nvim_buf_get_mark(0, '[') -- start of operated region
  local motion_end_pos = vim.api.nvim_buf_get_mark(0, ']') -- end of operated region
  if motion_start_pos[1] == 0 or motion_end_pos[1] == 0 then return end -- not set, didn't complete motion

  -- if we're running for the first time, we must be in insert mode, and not in normal mode doing dot-repeat
  -- if we're at `(|'')`, we want to select the `(`, not the `'`, so we offset backwards by 1
  local pair_col_offset = direction == nil and wrap_type == 'motion_reverse' and -1 or 0

  -- when running the operator for the first time, the global `cursor` variable will let us figure out if
  -- the direction is forward or backward
  -- on dot-repeat, we then use the stored `direction` variable
  if not direction then
    direction = cursor[1] == motion_end_pos[1] and cursor[2] == motion_end_pos[2] and 'backward' or 'forward'
  end
  local new_pair_pos = direction == 'backward' and motion_start_pos or { motion_end_pos[1], motion_end_pos[2] + 1 }
  new_pair_pos[1] = new_pair_pos[1] - 1 -- convert to 0-indexed

  local pair = motions.get_pair_at(
    direction == 'backward' and { motion_end_pos[1], motion_end_pos[2] + 1 } or motion_start_pos,
    pair_col_offset
  )
  if not pair or #pair ~= 2 then return end
  pair = wrap_type == 'motion_reverse' and pair[1] or pair[2]
  local pair_pos = { pair.line, pair.col }

  -- clamp to end of line
  local line_len = #vim.api.nvim_buf_get_lines(0, new_pair_pos[1], new_pair_pos[1] + 1, true)[1]
  new_pair_pos[2] = math.min(line_len, new_pair_pos[2])

  -- get pair and set it to the new position
  local paren = vim.api.nvim_buf_get_text(0, pair_pos[1], pair_pos[2], pair_pos[1], pair_pos[2] + 1, {})[1]
  vim.api.nvim_buf_set_text(0, new_pair_pos[1], new_pair_pos[2], new_pair_pos[1], new_pair_pos[2], { paren })

  -- move cursor to the pair
  vim.api.nvim_win_set_cursor(0, { new_pair_pos[1] + 1, new_pair_pos[2] + (wrap_type == 'motion_reverse' and 1 or 0) })

  -- clear pair at the original position
  if pair_pos[1] == new_pair_pos[1] and pair_pos[2] > new_pair_pos[2] then
    -- compensate for the new position being 1 character to the right of the original position
    -- since we inserted the character at the new position
    pair_pos[2] = pair_pos[2] + 1
    new_pair_pos[2] = new_pair_pos[2] + 1
  end
  vim.api.nvim_buf_set_text(0, pair_pos[1], pair_pos[2], pair_pos[1], pair_pos[2] + 1, {})
end

return motions
