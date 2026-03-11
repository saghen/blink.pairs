local mappings = require('blink.pairs.mappings')
local rust = require('blink.pairs.rust')
local motion = require('blink.pairs.mappings.wrap.motion')

local wrap = {}

local registrations = {
  motion = function(key, opts) wrap.register_motion(key, opts) end,
  motion_reverse = function(key, opts) wrap.register_motion(key, opts, true) end,
  treesitter = function(key) wrap.register_treesitter(key, 'fwd') end,
  treesitter_reverse = function(key) wrap.register_treesitter(key, 'rev') end,
  normal_mode_motion = function(key) wrap.register_normal_mode_motion(key) end,
  normal_mode_motion_reverse = function(key) wrap.register_normal_mode_motion(key, true) end,
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
    if key == 'normal_mode' then
      --- @cast def table<string, blink.pairs.WrapTypeNormal>
      for normal_mode_key, normal_mode_type in pairs(def) do
        local type = normal_mode_type == 'motion' and 'normal_mode_motion'
          or normal_mode_type == 'motion_reverse' and 'normal_mode_motion_reverse'
          or error('unknown type for normal mode wrap: ' .. normal_mode_type)
        registrations[type](normal_mode_key, { type = type })
      end
    else
      local opts = normalize_def(def)
      local fn = registrations[opts.type]
      if fn then
        fn(key, opts)
      else
        wrap.register_pair(key, def.type)
      end
    end
  end
end

--- @param definitions blink.pairs.WrapDefinitions
function wrap.unregister(definitions)
  for key, def in pairs(definitions) do
    if key == 'normal_mode' then
      --- @cast def table<string, blink.pairs.WrapTypeNormal>
      for normal_mode_key, _ in pairs(def) do
        vim.keymap.del('n', normal_mode_key)
      end
    else
      vim.keymap.del('i', key)
    end
  end
end

--- @param key string
--- @param opts? blink.pairs.WrapOpts
--- @param reverse? boolean
function wrap.register_motion(key, opts, reverse)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    -- subtract 1 from column in reverse mode, because at `(|'')`,
    -- we want to select the `(`, not the `'`
    local pair = wrap.get_pair_at_cursor(reverse and -1 or nil)
    if not pair or #pair < 2 then return key end

    if reverse then
      motion.set_operator_wrap({ pair[1].line + 1, pair[1].col + 1 }, opts)
      return '<C-g>U<C-o>g@'
    else
      local cursor = vim.api.nvim_win_get_cursor(0)
      cursor[2] = cursor[2] + 1 -- compensate for the `<Right>` movement
      motion.set_operator_wrap({ pair[2].line + 1, pair[2].col + 1 }, opts, cursor)
      return '<C-g>U<Right><C-o>g@'
    end
  end, { expr = true, desc = 'Wrap closing pair ' .. (reverse and 'backward' or 'forward') .. ' via motion' })
end

--- @param key string
--- @param reverse? boolean
function wrap.register_normal_mode_motion(key, reverse)
  vim.keymap.set('n', key, function()
    if not mappings.is_enabled() then return key end

    -- subtract 1 from column in reverse mode, because at `(|'')`,
    -- we want to select the `(`, not the `'`
    local pair = wrap.get_pair_at_cursor()
    if not pair or #pair < 2 then return key end

    if reverse then
      motion.set_operator_wrap({ pair[1].line + 1, pair[1].col + 1 })
    else
      motion.set_operator_wrap({ pair[2].line + 1, pair[2].col + 1 })
    end

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

    return '<C-g>U' .. pair .. '<C-o>g@'
  end, { expr = true, desc = 'Insert ' .. pair .. ' and wrap via motion' })
end

--- @param key string
--- @param direction 'fwd' | 'rev'
function wrap.register_treesitter(key, direction)
  local cmd = "<C-g>u<Cmd>lua require('blink.pairs.mappings.wrap.treesitter').wrap('" .. direction .. "')<CR>"
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end
    return cmd
  end, { expr = true, desc = 'TS node cycling wrap ' .. direction })
end

--- @param col_offset? integer
--- @return blink.pairs.MatchWithLine[]?
function wrap.get_pair_at_cursor(col_offset)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local bufnr = vim.api.nvim_get_current_buf()
  if col_offset then cursor[2] = math.max(cursor[2] + col_offset, 0) end
  return rust.get_surrounding_match_pair(bufnr, cursor[1] - 1, cursor[2])
end

return wrap
