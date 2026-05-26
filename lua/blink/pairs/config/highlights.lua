--- @class (exact) blink.pairs.HighlightsConfig
--- @field enabled boolean
--- @field cmdline boolean Requires `require('vim._extui').enable({})`
--- @field groups string[] | fun(match: blink.pairs.Match): string Highlight groups for matched pairs, in order that they'll appear based on depth, or a function that returns a highlight group for a given match
--- @field unmatched_group string Highlight group for unmatched pairs
--- @field priority number
--- @field ns integer
--- @field matchparen blink.pairs.MatchparenConfig

--- @class (exact) blink.pairs.MatchparenConfig
--- @field enabled boolean
--- @field cmdline boolean Requires `require('vim._extui').enable({})`. Disabled by default due to only showing matchparen when moving the cursor, and not when typing.
--- @field include_surrounding boolean Also include pairs not on top of the cursor, but surrounding the cursor
--- @field group string Highlight group for the matching pair
--- @field priority number Priority of the highlight

local types = require('blink.lib.config').types
return {
  enabled = { true, 'boolean' },
  cmdline = { true, 'boolean' },
  groups = { { 'BlinkPairsOrange', 'BlinkPairsPurple', 'BlinkPairsBlue' }, types.list('string') },
  unmatched_group = { 'BlinkPairsUnmatched', 'string' },
  priority = { 200, 'number' },
  ns = { vim.api.nvim_create_namespace('blink.pairs'), 'number' },
  matchparen = {
    enabled = { true, 'boolean' },
    cmdline = { false, 'boolean' },
    include_surrounding = { false, 'boolean' },
    group = { 'MatchParen', 'string' },
    priority = { 250, 'number' },
  },
}
