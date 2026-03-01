local mappings = {}

--- @type table<string, boolean>
local disabled_filetypes_set = {}

function mappings.enable()
  local config = require('blink.pairs.config')

  disabled_filetypes_set = {}
  for _, ft in ipairs(config.mappings.disabled_filetypes) do
    disabled_filetypes_set[ft] = true
  end

  require('blink.pairs.mappings.ops').register(config.mappings.pairs, config.mappings.cmdline)
  require('blink.pairs.mappings.wrap').register(config.mappings.wrap)
end

function mappings.disable()
  local config = require('blink.pairs.config')
  require('blink.pairs.mappings.ops').unregister(config.mappings.pairs, config.mappings.cmdline)
  require('blink.pairs.mappings.wrap').unregister(config.mappings.wrap)
end

function mappings.is_enabled()
  return vim.g.pairs ~= false
    and vim.b.pairs ~= false
    and vim.g.blink_pairs ~= false
    and vim.b.blink_pairs ~= false
    and vim.api.nvim_get_mode().mode:find('R') == nil
    and not disabled_filetypes_set[vim.bo.filetype]
end

return mappings
