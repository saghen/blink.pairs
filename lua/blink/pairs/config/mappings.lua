--- @class (exact) blink.pairs.MappingsConfig
--- @field enabled boolean
--- @field cmdline boolean
--- @field disabled_filetypes string[]
--- @field wrap blink.pairs.WrapDefinitions
--- @field pairs blink.pairs.RuleDefinitions

--- @alias blink.pairs.RuleDefinitions table<string, string | blink.pairs.RuleDefinition | blink.pairs.RuleDefinition[]>

--- @alias blink.pairs.WrapType 'motion' | 'motion_reverse' | 'treesitter' | 'treesitter_reverse' | '' | boolean | nil
--- @alias blink.pairs.WrapTypeNormal 'motion' | 'motion_reverse'

--- @alias blink.pairs.WrapValue blink.pairs.WrapType
--- @alias blink.pairs.WrapDefinitions table<string, blink.pairs.WrapValue> | { normal_mode: table<string, blink.pairs.WrapTypeNormal> }

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

local types = require('blink.lib.config').types

local wrap_enum = types.enum({ 'motion', 'motion_reverse', 'treesitter', 'treesitter_reverse', false })

-- stylua: ignore
return {
  enabled = { true, 'boolean' },
  cmdline = { true, 'boolean' },
  disabled_filetypes = { {}, 'table' },

  wrap = types.catchall(
    {
      -- move closing pair via motion
      ['<C-b>'] = { 'motion', wrap_enum },
      -- move opening pair via motion
      ['<C-S-b>'] = { 'motion_reverse', wrap_enum },
      -- treesitter node cycling: move closing pair to next/prev TS node boundary
      -- ['<C-l>'] = 'treesitter',
      -- ['<C-h>'] = 'treesitter_reverse',

      normal_mode = { {}, types.map(types.keycode, types.enum({ 'motion', 'motion_reverse', false })) },
    },
    types.keycode,
    wrap_enum
  ),

  pairs = {
    {
      ['!'] = { { '<!--', '-->', languages = { 'html', 'markdown', 'markdown_inline' } } },
      ['('] = ')',
      ['['] = {
        {
          '[', ']',
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
        { "''", when = function(ctx) return ctx:text_before_cursor(1) == "'" end, languages = { 'nix' } },
        { "'''", when = function(ctx) return ctx:text_before_cursor(2) == "''" end, languages = { 'python', 'toml' } },
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
              and ctx.ft ~= 'fennel'
              and (not ctx.char_under_cursor:match('%w') or ctx:is_after_cursor("'"))
              and ctx.ts:blacklist('singlequote').matches
          end,
        },
      },
      ['"'] = {
        { 'r#"', '"#', languages = { 'rust' }, priority = 100 },
        {
          '"""',
          when = function(ctx) return ctx:text_before_cursor(2) == '""' end,
          languages = { 'python', 'elixir', 'julia', 'kotlin', 'scala', 'toml' },
        },
        { '"', enter = false, space = false },
      },
      ['`'] = {
        {
          '```',
          when = function(ctx) return ctx:text_before_cursor(2) == '``' end,
          languages = { 'markdown', 'markdown_inline', 'typst', 'vimwiki', 'rmarkdown', 'rmd', 'quarto' },
        },
        { '`', "'", languages = { 'bibtex', 'latex', 'plaintex' } },
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
        { '*', when = function(ctx) return ctx.ts:blacklist('asterisk').matches end, languages = { 'typst' } },
      },
      ['<'] = {
        { '<', '>', when = function(ctx) return ctx.ts:whitelist('angle').matches end, languages = { 'rust' } },
      },
      ['$'] = {
        { '$', languages = { 'markdown', 'markdown_inline', 'typst', 'latex', 'plaintex' } },
      },
    },

    types.map(
      'string',
      {
        'string',
        types.list(
          types.table({
            [1] = 'string',
            [2] = { 'string', 'nil' },
            cmdline = { 'boolean', 'nil' },
            priority = { 'number', 'nil' },
            languages = { types.list('string'), 'nil' },
            when = { 'function', 'nil' },
            enter = { 'boolean', 'function', 'nil' },
            backspace = { 'boolean', 'function', 'nil' },
            space = { 'boolean', 'function', 'nil' },
          })
        )
      }
    )
  },
}
