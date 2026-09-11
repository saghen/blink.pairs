local mappings = require('blink.pairs.mappings')

local wrap = {}

--- Calls the callback for each enabled key in the definitions, with its mode
--- @param definitions blink.pairs.WrapDefinitions
--- @param callback fun(mode: 'i' | 'n', key: string, type: blink.pairs.WrapType)
local function for_each(definitions, callback)
  for key, type in pairs(definitions) do
    if key == 'normal_mode' then
      --- @cast type table<string, blink.pairs.WrapTypeNormal>
      for normal_key, normal_type in pairs(type) do
        if normal_type and normal_type ~= '' then callback('n', normal_key, normal_type) end
      end
    elseif type and type ~= '' then
      callback('i', key, type)
    end
  end
end

--- @param definitions blink.pairs.WrapDefinitions
function wrap.register(definitions)
  for_each(definitions, function(mode, key, type)
    if type == 'motion' or type == 'motion_reverse' then
      wrap.register_motion(mode, key, type)
    elseif (type == 'treesitter' or type == 'treesitter_reverse') and mode == 'i' then
      wrap.register_treesitter(key, type == 'treesitter' and 'fwd' or 'rev')
    else
      error('unknown type for wrap: ' .. tostring(type))
    end
  end)
end

--- @param definitions blink.pairs.WrapDefinitions
function wrap.unregister(definitions)
  for_each(definitions, function(mode, key) vim.keymap.del(mode, key) end)
end

--- @param mode 'i' | 'n'
--- @param key string
--- @param type 'motion' | 'motion_reverse'
function wrap.register_motion(mode, key, type)
  vim.keymap.set(mode, key, function()
    if not mappings.is_enabled() then return key end
    require('blink.pairs.mappings.wrap.motion').set_operator_wrap(type)
    -- <C-\><C-o> runs the operator from insert mode without moving the cursor at the end of the line
    return mode == 'i' and '<C-\\><C-o>g@' or 'g@'
  end, {
    expr = true,
    desc = 'Wrap ' .. (type == 'motion_reverse' and 'opening' or 'closing') .. ' pair via motion',
  })
end

--- @param key string
--- @param direction 'fwd' | 'rev'
function wrap.register_treesitter(key, direction)
  local cmd = "<C-g>U<Cmd>lua require('blink.pairs.mappings.wrap.treesitter').wrap('" .. direction .. "')<CR>"
  vim.keymap.set('i', key, function()
    if not mappings.is_enabled() then return key end
    return cmd
  end, { expr = true, desc = 'TS node cycling wrap ' .. direction })
end

return wrap
