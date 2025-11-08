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

      local index_of_key = rule.opening:find(key)
      assert(index_of_key ~= nil, 'Key not found in rule (temporary limitation, contributions welcome!)')
      index_of_key = index_of_key - 1

      local opening_prefix = rule.opening:sub(1, index_of_key)

      -- I.e. user types '"' for line 'r#|', we expand to 'r#""#'
      -- or the pair is "'''", in which case the index_of_key is 0 because there's no relevant prefix
      if index_of_key == 0 or ctx:is_before_cursor(opening_prefix) then
        return ops.open_pair(ctx, key, rule, index_of_key + 1)
      end

      --- I.e. for line 'r#"', user types '"' to close the pair
      if ctx:is_before_cursor(rule.opening) then return ops.close_pair(ctx, key, rule) end
    end

    -- No applicable rule found
    return key
  end
end

--- @param amount number
--- @return string keycodes Characters to feed to neovim to move the cursor forward or backward
function ops.shift_keycode(amount)
  local undo = vim.api.nvim_get_mode().mode ~= 'c' and '<C-g>u' or ''
  if amount > 0 then return string.rep(undo .. '<Right>', amount) end
  return string.rep(undo .. '<Left>', -amount)
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

  -- ( ( |) -> ( (  )|)
  if
    ctx.parser.get_unmatched_opening_before(ctx.bufnr, rule.opening, rule.closing, ctx.cursor.row - 1, ctx.cursor.col)
    ~= nil
  then
    return rule.closing
  end

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

--- @param rules blink.pairs.Rule[]
function ops.backspace(rules)
  return function()
    if not mappings.is_enabled() then return '<BS>' end

    local ctx = require('blink.pairs.context').new()
    local rule, surrounding_space = rule_lib.get_surrounding(ctx, rules, 'backspace')
    if rule == nil then return '<BS>' end

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
