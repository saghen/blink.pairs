local mappings = require('blink.pairs.mappings')

local wrap = {}

local registrations = {
  motion = function(key, type) wrap.register_motion(key, type) end,
  motion_reverse = function(key, type) wrap.register_motion(key, type) end,
  treesitter = function(key) wrap.register_treesitter(key, 'fwd') end,
  treesitter_reverse = function(key) wrap.register_treesitter(key, 'rev') end,
  normal_mode_motion = function(key) wrap.register_normal_mode_motion(key, 'motion') end,
  normal_mode_motion_reverse = function(key) wrap.register_normal_mode_motion(key, 'motion_reverse') end,
}

--- @param definitions blink.pairs.WrapDefinitions
function wrap.register(definitions)
  for key, def in pairs(definitions) do
    if key == 'normal_mode' then
      --- @cast def table<string, blink.pairs.WrapTypeNormal>
      for normal_mode_key, normal_mode_def in pairs(def) do
        if normal_mode_def ~= nil and normal_mode_def ~= false and normal_mode_def ~= '' then
          local type = normal_mode_def == 'motion' and 'normal_mode_motion'
            or normal_mode_def == 'motion_reverse' and 'normal_mode_motion_reverse'
            or error('unknown type for normal mode wrap: ' .. normal_mode_def)
          registrations[type](normal_mode_key)
        end
      end
    elseif def ~= nil and def ~= false and def ~= '' then
      registrations[def](key, def)
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
--- @param type blink.pairs.WrapType
function wrap.register_motion(key, type)
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end
    local motion = require('blink.pairs.mappings.wrap.motion')
    motion.set_operator_wrap(type)
    return '<C-o>g@'
  end, {
    expr = true,
    desc = 'Wrap ' .. (type == 'motion_reverse' and 'opening' or 'closing') .. ' pair via motion',
  })
end

--- @param key string
--- @param type blink.pairs.WrapType
function wrap.register_normal_mode_motion(key, type)
  vim.keymap.set('n', key, function()
    if not mappings.is_enabled() then return key end
    local motion = require('blink.pairs.mappings.wrap.motion')
    motion.set_operator_wrap(type)
    return 'g@'
  end, { expr = true, desc = 'Wrap pair at cursor via motion' })
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
