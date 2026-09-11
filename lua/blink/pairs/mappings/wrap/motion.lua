local nvim = require('blink.lib.nvim')
local rust = require('blink.pairs.rust')

local OPERATOR_FUNC = 'v:lua.blink_pairs_wrap'

local motions = {}

--- @type 'motion' | 'motion_reverse' | nil
local wrap_type
--- Cursor when the operator was started, before the motion. `between` is true when the cursor was
--- between characters (insert mode) rather than on a character (normal mode)
--- @type { [1]: integer, [2]: integer, between: boolean }?
local cursor

--- Perform setup for the wrap operator, storing the wrap type used by the operator
--- @param type 'motion' | 'motion_reverse'
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

--- @param a [integer, integer]
--- @param b [integer, integer]
local function before(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end

--- Must be a _G global because vim's operatorfunc requires v:lua.<name>
--- Moves the opening (motion_reverse) or closing (motion) delimiter of the pair surrounding the
--- cursor to the start (backward motion) or end (forward motion, text object) of the operated region
--- @param mode 'char' | 'line' | 'block'
_G.blink_pairs_wrap = function(mode)
  local start_cursor = cursor
  cursor = nil
  if not wrap_type or not start_cursor or mode == 'block' then return end

  local bufnr = nvim.get_current_buf()
  local pair = rust.get_surrounding_match_pair(bufnr, start_cursor[1] - 1, start_cursor[2], start_cursor.between)
  if not pair then return end
  local is_open = wrap_type == 'motion_reverse'
  local match = is_open and pair[1] or pair[2]
  local text = is_open and match[1] or (match[2] or match[1])
  local from = { match.line, match.col }

  local origin = { start_cursor[1] - 1, start_cursor[2] }
  local region_start = nvim.buf_get_mark(0, '[')
  local region_end = nvim.buf_get_mark(0, ']')
  region_start[1] = region_start[1] - 1
  region_end[1] = region_end[1] - 1
  -- linewise motions cover whole lines, regardless of the columns of the marks
  if mode == 'line' then
    origin[2], region_start[2], region_end[2] = 0, 0, math.huge
  end

  local to
  if before(region_start, origin) then
    to = region_start
  else
    -- move past the (potentially multi-byte) character at the end of the region, if any
    local line = nvim.buf_get_lines(0, region_end[1], region_end[1] + 1, true)[1]
    local col = math.min(region_end[2], #line)
    if col < #line then col = col + vim.str_utf_end(line, col + 1) + 1 end
    to = { region_end[1], col }
  end

  -- never move the delimiter past its counterpart, which would invert the pair
  local other = is_open and { pair[2].line, pair[2].col } or { pair[1].line, pair[1].col + #pair[1][1] }
  if is_open and before(other, to) or not is_open and before(to, other) then return end

  -- remove the delimiter, then insert it at the target, adjusting for the removal on the same line
  nvim.buf_set_text(bufnr, from[1], from[2], from[1], from[2] + #text, {})
  if to[1] == from[1] and to[2] > from[2] then to[2] = to[2] - #text end
  nvim.buf_set_text(bufnr, to[1], to[2], to[1], to[2], { text })

  -- place the cursor inside the pair, next to the moved delimiter
  nvim.win_set_cursor(0, { to[1] + 1, to[2] + (is_open and #text or 0) })
end

return motions
