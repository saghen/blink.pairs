
local mappings = {}

function mappings.enable()
  local config = require('blink.pairs.config')
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
    and not vim.tbl_contains(require('blink.pairs.config').mappings.disabled_filetypes, vim.bo.filetype)
end

return mappings
