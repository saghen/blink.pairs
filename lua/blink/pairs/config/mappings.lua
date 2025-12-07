--- @class (exact) blink.pairs.MappingsConfig
--- @field enabled boolean
--- @field cmdline boolean
--- @field disabled_filetypes string[]
--- @field pairs blink.pairs.RuleDefinitions

--- @alias blink.pairs.RuleDefinitions table<string, string | blink.pairs.RuleDefinition | blink.pairs.RuleDefinition[]>

--- @class (exact) blink.pairs.RuleDefinition
--- @field [1] string Closing character (e.g. { ')' }) or opening character if two characters are provided (e.g. {'(', ')'})
--- @field [2]? string Closing character (e.g. {'(', ')'})
--- @field priority? number
--- @field cmdline? boolean
--- @field languages? string[]
--- @field when? fun(ctx: blink.pairs.Context): boolean
--- @field open? boolean | fun(ctx: blink.pairs.Context): boolean Whether to open the pair
--- @field close? boolean | fun(ctx: blink.pairs.Context): boolean Whether to close the pair
--- @field open_or_close? boolean | fun(ctx: blink.pairs.Context): boolean Whether to open or close the pair, used in-place of `open` and `close` when the open and close are the same (such as for '' or "")
--- @field enter? boolean | fun(ctx: blink.pairs.Context): boolean
--- @field backspace? boolean | fun(ctx: blink.pairs.Context): boolean
--- @field space? boolean | fun(ctx: blink.pairs.Context): boolean

local validate = require('blink.pairs.config.utils').validate
local mappings = {
  --- @type blink.pairs.MappingsConfig
  default = {
    enabled = true,
    cmdline = true,
    disabled_filetypes = {},
    pairs = {
      ['!'] = { { '<!--', '-->', languages = { 'html', 'markdown', 'markdown_inline' } } },
      ['('] = ')',
      ['['] = {
        {
          '[',
          ']',
          space = function(ctx)
            return not ctx.ts:is_language('markdown')
              -- ignore markdown todo items (bullets and numbered)
              or (
                not ctx:text_before_cursor():match('^%s*[%*%-+]%s+%[%s*$')
                and not ctx:text_before_cursor():match('^%s*%d+%.%s+%[%s*$')
              )
          end,
        },
      },
      ['{'] = '}',
      ["'"] = {
        {
          "'''",
          when = function(ctx) return ctx:text_before_cursor(2) == "''" end,
          languages = { 'python' },
        },
        {
          "'",
          enter = false,
          space = false,
          when = function(ctx)
            -- The `plaintex` filetype has no treesitter parser, so we can't disable
            -- this pair in math environments. Thus, disable this pair completely.
            -- TODO: disable inside "" strings?
            return ctx.ft ~= 'plaintext'
              and ctx.ft ~= 'scheme'
              and (not ctx.char_under_cursor:match('%w') or ctx:is_after_cursor("'"))
              and ctx.ts:blacklist('singlequote').matches
          end,
        },
      },
      ['"'] = {
        {
          'r#"',
          '"#',
          languages = { 'rust' },
          priority = 100,
        },
        {
          '"""',
          when = function(ctx) return ctx:text_before_cursor(2) == '""' end,
          languages = { 'python', 'elixir', 'julia', 'kotlin', 'scala' },
        },
        { '"', enter = false, space = false },
      },
      ['`'] = {
        {
          '```',
          when = function(ctx) return ctx:text_before_cursor(2) == '``' end,
          languages = { 'markdown', 'markdown_inline', 'typst', 'vimwiki', 'rmarkdown', 'rmd', 'quarto' },
        },
        {
          '`',
          "'",
          languages = { 'bibtex', 'latex', 'plaintex' },
        },
        { '`', enter = false, space = false },
      },
      ['_'] = {
        {
          '_',
          when = function(ctx) return not ctx.char_under_cursor:match('%w') and ctx.ts:blacklist('underscore').matches end,
          languages = { 'typst' },
        },
      },
      ['*'] = {
        {
          '*',
          when = function(ctx) return ctx.ts:blacklist('asterisk').matches end,
          languages = { 'typst' },
        },
      },
      ['<'] = {
        { '<', '>', when = function(ctx) return ctx.ts:whitelist('angle').matches end, languages = { 'rust' } },
      },
      ['$'] = {
        {
          '$',
          languages = { 'markdown', 'markdown_inline', 'typst', 'latex', 'plaintex' },
        },
      },
    },
  },
}

function mappings.validate(config)
  validate('mappings', {
    enabled = { config.enabled, 'boolean' },
    cmdline = { config.cmdline, 'boolean' },
    disabled_filetypes = { config.disabled_filetypes, 'table' },
    pairs = { config.pairs, 'table' },
  }, config)

  for key, defs in pairs(config.pairs) do
    mappings.validate_rules(key, defs)
  end
end

function mappings.validate_rules(key, defs)
  if type(defs) == 'string' then return end

  if not vim.islist(defs) then defs = { defs } end

  for i, def in ipairs(defs) do
    validate('mappings.pairs.[' .. key .. '].' .. i, {
      [1] = { def[1], 'string' },
      [2] = { def[2], { 'string', 'nil' } },
      cmdline = { def.cmdline, { 'boolean', 'nil' } },
      priority = { def.priority, { 'number', 'nil' } },
      languages = { def.languages, { 'table', 'nil' } },
      when = { def.when, { 'function', 'nil' } },
      enter = { def.enter, { 'boolean', 'function', 'nil' } },
      backspace = { def.backspace, { 'boolean', 'function', 'nil' } },
      space = { def.space, { 'boolean', 'function', 'nil' } },
    }, def)
  end
end

return mappings
