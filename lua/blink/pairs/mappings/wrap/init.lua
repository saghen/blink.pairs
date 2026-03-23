local mappings = require('blink.pairs.mappings')
local motion = require('blink.pairs.mappings.wrap.motion')

local wrap = {}

local registrations = {
  motion = function(key, opts) wrap.register_motion(key, opts) end,
  motion_reverse = function(key, opts) wrap.register_motion(key, opts) end,
  treesitter = function(key) wrap.register_treesitter(key, 'fwd') end,
  treesitter_reverse = function(key) wrap.register_treesitter(key, 'rev') end,
  normal_mode_motion = function(key) wrap.register_normal_mode_motion(key, { type = 'motion' }) end,
  normal_mode_motion_reverse = function(key) wrap.register_normal_mode_motion(key, { type = 'motion_reverse' }) end,
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
        registrations[type](normal_mode_key)
      end
    else
      local opts = normalize_def(def)
      local fn = registrations[opts.type]
      if fn then
        fn(key, opts)
      else
        wrap.register_pair(key, def.type, { type = 'motion' })
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
--- @param opts blink.pairs.WrapOpts
function wrap.register_motion(key, opts)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end
    motion.set_operator_wrap(opts)
    return '<C-o>g@'
  end, {
    expr = true,
    desc = 'Wrap ' .. (opts.type == 'motion_reverse' and 'opening' or 'closing') .. ' pair via motion',
  })
end

--- @param key string
--- @param opts blink.pairs.WrapOpts
function wrap.register_normal_mode_motion(key, opts)
  vim.keymap.set('n', key, function()
    if not mappings.is_enabled() then return key end
    motion.set_operator_wrap(opts)
    return 'g@'
  end, { expr = true, desc = 'Wrap pair at cursor via motion' })
end

--- @param key string
--- @param pair string
--- @param opts blink.pairs.WrapOpts
function wrap.register_pair(key, pair, opts)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end

    local cursor = vim.api.nvim_win_get_cursor(0)
    motion.set_operator_wrap(opts, { cursor[1], cursor[2] + #pair })

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

return wrap
