local nvim = require('blink.lib.nvim')
local rust = require('blink.pairs.rust')

local OPERATOR_FUNC = 'v:lua.blink_pairs_wrap'

local motions = {}

--- @type blink.pairs.WrapType?
local wrap_type
--- Cursor when the operator was started, before the motion: { row (1-indexed), col (0-indexed), between }
--- where `between` is true when the cursor was between characters (insert mode)
--- @type { [1]: integer, [2]: integer, between: boolean }?
local cursor

--- Perform setup for the wrap operator, storing the wrap type used by the operator
--- @param type blink.pairs.WrapType
function motions.set_operator_wrap(type)
  wrap_type = type
  vim.go.operatorfunc = OPERATOR_FUNC
end

-- The operator receives the region of the motion, but not where the cursor was before it, which we
-- need to determine the surrounding pair and the direction of the motion. We grab it when entering
-- operator-pending mode, which also works for dot-repeat where the mapping isn't invoked
nvim.create_autocmd('ModeChanged', {
  group = nvim.create_augroup('blink.pairs.wrap.motion', {}),
  pattern = '*:no*',
  callback = function(ev)
    if vim.go.operatorfunc ~= OPERATOR_FUNC then return end
    cursor = nvim.win_get_cursor(0)
    cursor.between = ev.match:sub(1, 3) == 'niI'
  end,
})

--- Must be a _G global because vim's operatorfunc requires v:lua.<name>
--- Moves the opening (motion_reverse) or closing (motion) delimiter of the pair surrounding the
--- cursor to the end (forward motion) or start (backward motion) of the operated region
--- @param mode 'char' | 'line' | 'block'
_G.blink_pairs_wrap = function(mode)
  local start_cursor = cursor
  cursor = nil
  if not wrap_type or not start_cursor or mode == 'block' then return end

  local bufnr = nvim.get_current_buf()
  local pair = rust.get_surrounding_match_pair(bufnr, start_cursor[1] - 1, start_cursor[2], start_cursor.between)
  if not pair then return end
  local open, close = pair[1], pair[2]
  local is_open = wrap_type == 'motion_reverse'
  local match = is_open and open or close
  local text = is_open and match[1] or (match[2] or match[1])

  -- region operated on, 0-indexed rows
  local region_start = nvim.buf_get_mark(0, '[')
  local region_end = nvim.buf_get_mark(0, ']')
  region_start[1] = region_start[1] - 1
  region_end[1] = region_end[1] - 1

  -- backward motions (e.g. `b`, `0`, `k`) move the delimiter to the start of the region, forward
  -- motions (e.g. `e`, `$`, `j`) and text objects (e.g. `aq`) to the end
  local backward = mode == 'line' and region_start[1] < start_cursor[1] - 1
    or mode == 'char'
      and (region_start[1] < start_cursor[1] - 1 or region_start[1] == start_cursor[1] - 1 and region_start[2] < start_cursor[2])
  local target
  if backward then
    target = { region_start[1], mode == 'line' and 0 or region_start[2] }
  else
    local line = nvim.buf_get_lines(0, region_end[1], region_end[1] + 1, true)[1]
    local col = mode == 'line' and #line or math.min(region_end[2], #line)
    -- move past the (potentially multi-byte) character at the end of the region
    if col < #line then col = col + vim.str_utf_end(line, col + 1) + 1 end
    target = { region_end[1], col }
  end

  -- never move the delimiter past its counterpart, which would invert the pair
  local before = function(a, b) return a[1] < b[1] or a[1] == b[1] and a[2] < b[2] end
  if is_open and before({ close.line, close.col }, target) then return end
  if not is_open and not before({ open.line, open.col + #open[1] }, { target[1], target[2] + 1 }) then return end

  -- remove the delimiter, then insert it at the target, adjusting for the removal on the same line
  nvim.buf_set_text(bufnr, match.line, match.col, match.line, match.col + #text, {})
  if target[1] == match.line and target[2] > match.col then target[2] = target[2] - #text end
  nvim.buf_set_text(bufnr, target[1], target[2], target[1], target[2], { text })

  -- place the cursor inside the pair, next to the moved delimiter
  nvim.win_set_cursor(0, { target[1] + 1, target[2] + (is_open and #text or 0) })
end

return motions
