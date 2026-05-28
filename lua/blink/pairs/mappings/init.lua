local mappings = {}

--- @type table<string, boolean>
local disabled_filetypes_set = {}

function mappings.enable()
  local config = require('blink.pairs.config').snapshot()

  disabled_filetypes_set = {}
  for _, ft in ipairs(config.mappings.disabled_filetypes) do
    disabled_filetypes_set[ft] = true
  end

  require('blink.pairs.mappings.ops').register(config.mappings.pairs, config.mappings.cmdline)
  require('blink.pairs.mappings.wrap').register(config.mappings.wrap)
end

function mappings.disable()
  local config = require('blink.pairs.config').snapshot()
  require('blink.pairs.mappings.ops').unregister(config.mappings.pairs, config.mappings.cmdline)
  require('blink.pairs.mappings.wrap').unregister(config.mappings.wrap)
end

function mappings.is_enabled()
  local mode = vim.api.nvim_get_mode().mode
  return vim.g.pairs ~= false
    and vim.b.pairs ~= false
    and vim.g.blink_pairs ~= false
    and vim.b.blink_pairs ~= false
    and mode:find('R') == nil
    and (mode ~= 'c' or (vim.fn.getcmdtype() ~= '/' and vim.fn.getcmdtype() ~= '?'))
    and not disabled_filetypes_set[vim.bo.filetype]
end

return mappings
