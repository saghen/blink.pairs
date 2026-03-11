local mappings = require('blink.pairs.mappings')
local rust = require('blink.pairs.rust')
local motion = require('blink.pairs.mappings.wrap.motion')

local wrap = {}

local registrations = {
  in_pair = function(key, opts) wrap.register_in_pair(key, opts) end,
  reverse_in_pair = function(key, opts) wrap.register_reverse_in_pair(key, opts) end,
  ts_wrap = function(key) wrap.register_ts_wrap(key, 'fwd') end,
  ts_wrap_rev = function(key) wrap.register_ts_wrap(key, 'rev') end,
  normal_in_pair = function(key) wrap.register_normal_in_pair(key) end,
}

--- Normalize a wrap definition to table form
--- @param def blink.pairs.WrapValue
--- @return blink.pairs.WrapOpts
local function normalize_def(def)
  if type(def) == 'string' then return { type = def } end
  return def
end

--- @param definitions blink.pairs.WrapDefinitions
function wrap.register(definitions)
  for key, def in pairs(definitions) do
    local opts = normalize_def(def)
    local fn = registrations[opts.type]
    if fn then
      fn(key, opts)
    else
      wrap.register_pair(key, opts.type)
    end
  end
end

--- @param definitions blink.pairs.WrapDefinitions
function wrap.unregister(definitions)
  for key, def in pairs(definitions) do
    local opts = normalize_def(def)
    local mode = opts.type == 'normal_in_pair' and 'n' or 'i'
    vim.keymap.del(mode, key)
  end
end

--- @param key string
--- @param opts? blink.pairs.WrapOpts
function wrap.register_in_pair(key, opts)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    local cursor = vim.api.nvim_win_get_cursor(0)
    motion.set_operator_wrap({ cursor[1], cursor[2] + 1 }, opts)
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
    local start_pos = { open_match.line + 1, open_match.col + 1 } -- 1-indexed
    motion.set_operator_wrap_reverse(start_pos, opts)

    vim.api.nvim_win_set_cursor(0, { open_match.line + 1, open_match.col + #open_match[1] })

    return '<C-g>u<C-o>g@'
  end, { expr = true, desc = 'Wrap opening pair backward via motion' })
end

--- @param key string
function wrap.register_normal_in_pair(key)
  vim.keymap.set('n', key, function()
    if not mappings.is_enabled() then return key end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local bufnr = vim.api.nvim_get_current_buf()
    local match = rust.get_match_at(bufnr, cursor[1] - 1, cursor[2])
    if not match then return key end

    motion.set_operator_wrap({ cursor[1], cursor[2] + 1 })
    return 'g@'
  end, { expr = true, desc = 'Wrap pair at cursor via motion' })
end

--- @param key string
--- @param pair string
function wrap.register_pair(key, pair)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    local cursor = vim.api.nvim_win_get_cursor(0)
    motion.set_operator_wrap({ cursor[1], cursor[2] + #pair })

    return '<C-g>u' .. pair .. '<C-o>g@'
  end, { expr = true, desc = 'Insert ' .. pair .. ' and wrap via motion' })
end

--- @param key string
--- @param direction 'fwd' | 'rev'
function wrap.register_ts_wrap(key, direction)
  local cmd = "<C-g>u<Cmd>lua require('blink.pairs.mappings.wrap.treesitter').wrap('" .. direction .. "')<CR>"
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end
    return cmd
  end, { expr = true, desc = 'TS node cycling wrap ' .. direction })
end

return wrap
