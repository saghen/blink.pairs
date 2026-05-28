--- @class (exact) blink.pairs.ConfigStrict
--- @field mappings blink.pairs.MappingsConfig
--- @field highlights blink.pairs.HighlightsConfig
--- @field debug boolean

local config = require('blink.lib.config')
return config.new({
  mappings = require('blink.pairs.config.mappings'),
  highlights = require('blink.pairs.config.highlights'),
  debug = { false, 'boolean' },
}, { validate = false })
