local mappings = require('blink.pairs.mappings')
local utils = require('blink.pairs.utils')
local rule_lib = require('blink.pairs.rule')

local ops = {}

--- @param rule_definitions blink.pairs.RuleDefinitions
--- @param cmdline boolean
function ops.register(rule_definitions, cmdline)
  local rules_by_key = rule_lib.parse(rule_definitions)

  local map = function(lhs, rhs)
    vim.keymap.set('i', lhs, rhs, { silent = true, noremap = true, expr = true })
    if cmdline then vim.keymap.set('c', lhs, rhs, { silent = false, noremap = true, expr = true }) end
  end

  for key, rules in pairs(rules_by_key) do
    if #rules > 0 then map(key, ops.on_key(key, rules)) end
  end

  local all_rules = rule_lib.get_all(rules_by_key)
  map('<BS>', ops.backspace(all_rules))
  map('<CR>', ops.enter(all_rules))
  map('<Space>', ops.space(all_rules))
end

--- @param rule_definitions blink.pairs.RuleDefinitions
--- @param cmdline boolean
function ops.unregister(rule_definitions, cmdline)
  local rules_by_key = rule_lib.parse(rule_definitions)

  local unmap = function(lhs)
    vim.keymap.del('i', lhs)
    if cmdline then vim.keymap.del('c', lhs) end
  end

  for key, rules in pairs(rules_by_key) do
    if #rules > 0 then unmap(key) end
  end

  unmap('<BS>')
  unmap('<CR>')
  unmap('<Space>')
end

--- @param key string
--- @param rules blink.pairs.Rule[]
function ops.on_key(key, rules)
  return function()
    if not mappings.is_enabled() then return key end

    local ctx = require('blink.pairs.context').new()
    local active_rules = rule_lib.get_all_active(ctx, rules)

    for _, rule in ipairs(active_rules) do
      -- TODO: set lazyredraw to prevent flickering

      if rule.opening == rule.closing then return ops.open_or_close_pair(ctx, key, rule) end

      if #rule.opening == 1 then
        if rule.opening == key then return ops.open_pair(ctx, key, rule) end
        return ops.close_pair(ctx, key, rule)
      end

      -- Multiple characters

      if key == rule.key then
        local index_of_key = rule.opening:find(key, 1, true)
        index_of_key = index_of_key ~= nil and index_of_key - 1 or 0

        local opening_prefix = rule.opening:sub(1, index_of_key)

        -- I.e. user types '"' for line 'r#|', we expand to 'r#""#'
        -- or the pair is "'''", in which case the index_of_key is 0 because there's no relevant prefix
        if index_of_key == 0 or ctx:is_before_cursor(opening_prefix) then
          return ops.open_pair(ctx, key, rule, index_of_key + 1)
        end
      end

      if key == rule.closing:sub(1, 1) and ctx:is_after_cursor(rule.closing, true) then
        return ops.close_pair(ctx, key, rule)
      end
    end

    -- No applicable rule found
    return key
  end
end

--- @param amount number
--- @return string keycodes Characters to feed to neovim to move the cursor forward or backward
function ops.shift_keycode(amount)
  local non_undo = vim.api.nvim_get_mode().mode ~= 'c' and '<C-g>U' or ''
  if amount > 0 then return string.rep(non_undo .. '<Right>', amount) end
  return string.rep(non_undo .. '<Left>', -amount)
end

--- Whether a multi-character closing belongs to an opening before the cursor.
--- The textual fallback also supports HTML comments in filetypes without an internal parser.
local function inside_multichar_pair(ctx, rule)
  local row = ctx.cursor.row - 1
  while row >= 0 do
    local line = row == ctx.cursor.row - 1 and ctx:text_before_cursor()
      or vim.api.nvim_buf_get_lines(ctx.bufnr, row, row + 1, false)[1]
    local opening, closing = 0, 0
    for _, item in ipairs({ { rule.opening, 'opening' }, { rule.closing, 'closing' } }) do
      local start = 1
      while true do
        local pos = line:find(item[1], start, true)
        if not pos then break end
        if item[2] == 'opening' then
          opening = pos
        else
          closing = pos
        end
        start = pos + #item[1]
      end
    end
    if opening > 0 or closing > 0 then return opening > closing end
    if ctx.mode:match('c') then return false end
    row = row - 1
  end
  return false
end

--- Skip only parsed, matched delimiters and whitespace on the current line.
--- @param ctx blink.pairs.Context
--- @param rule blink.pairs.Rule
--- @return string? keycodes
function ops.fly(ctx, rule)
  if ctx.mode:match('c') or not require('blink.pairs.config').mappings.fly.enabled then return end
  local row, col = ctx.cursor.row - 1, ctx.cursor.col
  for _, match in ipairs(ctx.parser.get_line_matches(ctx.bufnr, row)) do
    if match.col >= col then
      if ctx.line:sub(col + 1, match.col):find('%S') then return end
      local pair = ctx.parser.get_match_pair(ctx.bufnr, row, match.col)
      if not pair then return end
      local opening, closing = pair[1], pair[2]
      if
        closing.line == row
        and closing.col == match.col
        and opening[1] == rule.opening
        and (closing[2] or closing[1]) == rule.closing
        and (opening.line < row or opening.col < ctx.cursor.col)
      then
        return ops.shift_keycode(closing.col + #rule.closing - ctx.cursor.col)
      end
      col = match.col + #(match[2] or match[1])
    end
  end
end

--- @param ctx blink.pairs.Context
--- @param key string
--- @param rule blink.pairs.Rule
--- @param offset? number
function ops.open_pair(ctx, key, rule, offset)
  if not rule.open(ctx) then return key end

  -- \| -> \(|
  if ctx.is_escaped then return key end

  -- |) -> (|)
  if
    ctx.parser.get_unmatched_closing_after(ctx.bufnr, rule.opening, rule.closing, ctx.cursor.row - 1, ctx.cursor.col)
    ~= nil
  then
    return key
  end

  -- | -> (|)
  return rule.opening:sub(offset or 0) .. rule.closing .. ops.shift_keycode(-#rule.closing)
end

--- @param ctx blink.pairs.Context
--- @param key string
--- @param rule blink.pairs.Rule
function ops.close_pair(ctx, key, rule)
  if not rule.close(ctx) then return key end

  if #rule.closing > 1 then
    local offset = ctx:is_after_cursor(rule.closing) and 0 or ctx:is_after_cursor(rule.closing, true) and 1
    if offset and inside_multichar_pair(ctx, rule) then return ops.shift_keycode(offset + #rule.closing) end
    return key
  end

  -- ( ( |) -> ( (  )|)
  if
    ctx.parser.get_unmatched_opening_before(ctx.bufnr, rule.opening, rule.closing, ctx.cursor.row - 1, ctx.cursor.col)
    ~= nil
  then
    return rule.closing
  end

  local fly_keys = ops.fly(ctx, rule)
  if fly_keys then return fly_keys end

  -- TODO: should these use rule.closing.len()
  -- |) -> )|
  if ctx:text_after_cursor(1) == rule.closing:sub(1, 1) then return ops.shift_keycode(#rule.closing) end
  -- | ) ->  )|
  if ctx:text_after_cursor(2) == ' ' .. rule.closing then return ops.shift_keycode(2) end

  return rule.closing
end

--- @param ctx blink.pairs.Context
--- @param key string
--- @param rule blink.pairs.Rule
function ops.open_or_close_pair(ctx, key, rule)
  if not rule.open_or_close(ctx) then return key end

  -- \| -> \"|
  if ctx.is_escaped then return key end

  local pair = rule.opening
  assert(pair == rule.closing, 'Opening and closing must be the same')

  -- |' -> '|
  if ctx:is_after_cursor(pair) then return ops.shift_keycode(#pair) end

  -- 'foo| -> 'foo'|
  -- |foo' -> '|foo'
  local row, col = ctx.cursor.row - 1, ctx.cursor.col
  if
    ctx.parser.get_unterminated_opening_before(ctx.bufnr, pair, row, col) ~= nil
    or ctx.parser.get_unterminated_opening_after(ctx.bufnr, pair, row, col) ~= nil
  then
    return pair
  end

  -- Multiple character open
  -- '|' -> '''|'''
  if #rule.opening > 1 then
    local start_overlap = utils.find_overlap(ctx:text_before_cursor(), rule.opening)
    local end_overlap = utils.find_overlap(ctx:text_after_cursor(), rule.closing)
    local opening = rule.opening:sub(start_overlap + 1)
    local closing = rule.closing:sub(1, #rule.closing - end_overlap)

    return opening .. closing .. ops.shift_keycode(-#closing)
  end

  -- | -> '|'
  return pair .. pair .. ops.shift_keycode(-#pair)
end

--- @param ctx blink.pairs.Context
--- @param rules blink.pairs.Rule[]
--- @return blink.pairs.Rule?
--- @return integer? closing_indent
function ops.get_multiline_surrounding(ctx, rules)
  if ctx.mode:match('c') or ctx.cursor.row <= 1 or ctx.line:find('%S') then return end

  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, ctx.cursor.row - 2, ctx.cursor.row + 1, false)
  local previous_line = lines[1]
  local next_line = lines[3]
  if previous_line == nil or next_line == nil then return end

  local closing_indent = #next_line:match('^%s*')
  local next_text = next_line:sub(closing_indent + 1)

  for _, rule in ipairs(rules) do
    if
      rule_lib.is_active(ctx, rule, 'backspace')
      and previous_line:sub(-#rule.opening) == rule.opening
      and next_text:sub(1, #rule.closing) == rule.closing
      and next_text:sub(#rule.closing + 1):match('^%s*$')
    then
      return rule, closing_indent
    end
  end
end

--- Collapse an empty expanded pair outside the expression mapping's textlock.
function ops.backspace_multiline()
  local fallback = function() vim.api.nvim_feedkeys(vim.keycode('<BS>'), 'n', false) end
  if not mappings.is_enabled() then return fallback() end
  local ctx = require('blink.pairs.context').new()
  local rules = rule_lib.get_all(rule_lib.parse(require('blink.pairs.config').mappings.pairs))
  local rule, indent = ops.get_multiline_surrounding(ctx, rules)
  if not rule then return fallback() end
  local previous_row = ctx.cursor.row - 2
  local previous_line = vim.api.nvim_buf_get_lines(ctx.bufnr, previous_row, previous_row + 1, false)[1]
  vim.api.nvim_buf_set_text(ctx.bufnr, previous_row, #previous_line, previous_row + 2, indent, {})
  vim.api.nvim_win_set_cursor(0, { previous_row + 1, #previous_line })
end

--- Finds an active backspace rule whose complete opening is immediately before the cursor.
--- @param ctx blink.pairs.Context
--- @param rules blink.pairs.Rule[]
--- @return blink.pairs.Rule?
local function get_opening_before_cursor(ctx, rules)
  for _, rule in ipairs(rules) do
    if ctx:is_before_cursor(rule.opening) and rule_lib.is_active(ctx, rule, 'backspace') then
      local col, escapes = ctx.cursor.col - #rule.opening, 0
      while col > 0 and ctx.line:sub(col, col) == '\\' do
        escapes, col = escapes + 1, col - 1
      end
      if escapes % 2 == 0 then return rule end
    end
  end
end

--- Runs outside the expression mapping's textlock to remove a distant closing pair.
--- @return nil
function ops.backspace_overjumps()
  local fallback = function() vim.api.nvim_feedkeys(vim.keycode('<BS>'), 'n', false) end
  if not mappings.is_enabled() or not require('blink.pairs.config').mappings.backspace.overjumps then
    return fallback()
  end
  local ctx = require('blink.pairs.context').new()
  if ctx.mode:match('c') then return fallback() end
  local rules = rule_lib.get_all(rule_lib.parse(require('blink.pairs.config').mappings.pairs))
  local rule = get_opening_before_cursor(ctx, rules)
  if not rule or not require('blink.pairs.watcher').attach(ctx.bufnr) then return fallback() end
  local row, col = ctx.cursor.row - 1, ctx.cursor.col - #rule.opening
  local pair = ctx.parser.get_match_pair(ctx.bufnr, row, col)
  if not pair then return fallback() end
  local opening, closing = pair[1], pair[2]
  if
    opening.line ~= row
    or opening.col ~= col
    or opening[1] ~= rule.opening
    or (closing[2] or closing[1]) ~= rule.closing
  then
    return fallback()
  end

  -- Delete the closing first so the opening position stays valid. Preserve the contents and cursor.
  vim.api.nvim_buf_set_text(ctx.bufnr, closing.line, closing.col, closing.line, closing.col + #rule.closing, {})
  vim.cmd('undojoin')
  vim.api.nvim_buf_set_text(ctx.bufnr, row, col, row, ctx.cursor.col, {})
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

--- @param rules blink.pairs.Rule[]
function ops.backspace(rules)
  return function()
    if not mappings.is_enabled() then return '<BS>' end

    local ctx = require('blink.pairs.context').new()
    if ops.get_multiline_surrounding(ctx, rules) then
      return "<Cmd>lua require('blink.pairs.mappings.ops').backspace_multiline()<CR>"
    end
    local rule, surrounding_space = rule_lib.get_surrounding(ctx, rules, 'backspace')
    if rule == nil then
      if
        not ctx.mode:match('c')
        and require('blink.pairs.config').mappings.backspace.overjumps
        and get_opening_before_cursor(ctx, rules)
      then
        return "<Cmd>lua require('blink.pairs.mappings.ops').backspace_overjumps()<CR>"
      end
      return '<BS>'
    end

    -- ( | ) -> (|)
    -- TODO: disable in strings
    if surrounding_space then return '<Del><BS>' end

    -- (|) -> |
    return ops.shift_keycode(#rule.closing) .. string.rep('<BS>', #rule.opening + #rule.closing)
  end
end

--- @param rules blink.pairs.Rule[]
function ops.enter(rules)
  return function()
    -- use <C-]> to expand abbreviations
    if not mappings.is_enabled() then return '<C-]><CR>' end

    local ctx = require('blink.pairs.context').new()
    local rule, surrounding_space = rule_lib.get_surrounding(ctx, rules, 'enter')
    if rule == nil then return '<C-]><CR>' end

    if surrounding_space then return ops.shift_keycode(1) .. '<BS><BS>' .. '<CR><C-o>O' end

    -- (|) ->
    -- (
    --   |
    -- )
    return '<CR><C-o>O'
  end
end

--- @param rules blink.pairs.Rule[]
function ops.space(rules)
  return function()
    -- use <C-]> to expand abbreviations
    if not mappings.is_enabled() then return '<C-]><Space>' end

    local ctx = require('blink.pairs.context').new()
    local rule = rule_lib.get_surrounding(ctx, rules, 'space')
    if rule == nil then return '<C-]><Space>' end

    -- "(|)" -> "( | )"
    return '<Space><Space>' .. ops.shift_keycode(-1)
  end
end

return ops
