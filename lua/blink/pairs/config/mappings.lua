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

local validate = require('blink.pairs.config.utils').validate
local mappings = {
  --- @type blink.pairs.MappingsConfig
  default = {
    enabled = true,
    cmdline = true,
    disabled_filetypes = {},
    wrap = {
      -- move closing pair via motion
      ['<C-b>'] = 'motion',
      -- move opening pair via motion
      ['<C-S-b>'] = 'motion_reverse',
      -- treesitter node cycling: move closing pair to next/prev TS node boundary
      -- ['<C-l>'] = 'treesitter',
      -- ['<C-h>'] = 'treesitter_reverse',

      normal_mode = {
        -- move closing pair via motion
        -- ['<C-b>'] = 'motion',
        -- move opening pair via motion
        -- ['<C-S-b>'] = 'motion_reverse',
      },
    },
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
          "''",
          when = function(ctx) return ctx:text_before_cursor(1) == "'" end,
          languages = { 'nix' },
        },
        {
          "'''",
          when = function(ctx) return ctx:text_before_cursor(2) == "''" end,
          languages = { 'python', 'toml' },
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
              and ctx.ft ~= 'fennel'
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
    wrap = { config.wrap, 'table' },
    pairs = { config.pairs, 'table' },
  }, config)

  for key, defs in pairs(config.pairs) do
    mappings.validate_rules(key, defs)
  end
  mappings.validate_wrap('mappings.wrap', config.wrap)
end

function mappings.validate_wrap(key, defs)
  local validation_schema = { normal_mode = { defs.normal_mode, 'table' } }
  for wrap_key, def in pairs(defs) do
    if wrap_key == 'normal_mode' then
      if type(def) == 'table' then mappings.validate_normal_mode_wrap(key .. '.' .. wrap_key, def) end
    else
      validation_schema[wrap_key] = {
        def,
        function(val)
          return vim.tbl_contains({ 'motion', 'motion_reverse', 'treesitter', 'treesitter_reverse', '' }, val)
            or val == false
            or val == nil
        end,
        'one of "motion", "motion_reverse", "treesitter", "treesitter_reverse"',
      }
    end
  end

  validate(key, validation_schema, defs)
end

function mappings.validate_normal_mode_wrap(key, defs)
  local validation_schema = {}
  for wrap_key, def in pairs(defs) do
    validation_schema[wrap_key] = {
      def,
      function(val) return vim.tbl_contains({ 'motion', 'motion_reverse', '' }, val) or val == false or val == nil end,
      'one of "motion", "motion_reverse"',
    }
  end

  validate(key, validation_schema, defs)
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
