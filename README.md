# Blink Pairs (blink.pairs)

Rainbow highlighting, auto-pairs and wrapping for Neovim. Uses a custom parser internally which takes ~2ms to parse a 400k character file, and ~0.15ms for incremental updates. It uses indent-aware matching of delimiters and highlights mismatched pairs. See [the roadmap](https://github.com/Saghen/blink.pairs/issues/9) for the current status, contributions welcome!

## Behavior

The behavior was inspired by [lexima.vim](https://github.com/cohama/lexima.vim) and [nvim-autopairs](https://github.com/windwp/nvim-autopairs)

| Before   | Input   | After    |
|----------|---------|----------|
| `\|`       | `(`       | `(\|)`     |
| `\|)`      | `(`       | `(\|)`     |
| `\|`       | `"`       | `"\|"`     |
| `""\|`     | `"`       | `"""\|"""` |
| `''\|`     | `'`       | `'''\|'''` |
| `\\|`       | `[`       | `\[\|`     |
| `\\|`       | `"`       | `\"\|`     |
| `\\|`       | `'`       | `\'\|`     |
| `A`        | `'`       | `A'`       |
| `(\|)`     | `)`       | `()\|`     |
| `((\|)`     | `)`       | `(()\|)`     |
| `'\|'`     | `'`       | `''\|`     |
| `'''\|'''` | `'`       | `''''''\|` |
| `(\|)`     | `<BS>`    | `\|`       |
| `'\|'`     | `<BS>`    | `\|`       |
| `( \| )`   | `<BS>`    | `(\|)`     |
| `(\|)`     | `<Space>` | `( \| )`   |
| `foo(\|)'bar'`     | `<C-t>aq` | `foo('bar'\|)`   |

## Installation

```lua
{
  'saghen/blink.pairs',
  version = '*', -- (recommended) only required with prebuilt binaries

  -- download prebuilt binaries from github releases
  dependencies = 'saghen/blink.download',
  -- OR build from source, requires nightly:
  -- https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
  -- build = 'cargo build --release',
  -- If you use nix, you can build from source using latest nightly rust with:
  -- build = 'nix run .#build-plugin',

  --- @module 'blink.pairs'
  --- @type blink.pairs.Config
  opts = {
    mappings = {
      -- you can call require("blink.pairs.mappings").enable()
      -- and require("blink.pairs.mappings").disable()
      -- to enable/disable mappings at runtime
      enabled = true,
      cmdline = true,
      -- or disable with `vim.g.pairs = false` (global) and `vim.b.pairs = false` (per-buffer)
      -- and/or with `vim.g.blink_pairs = false` and `vim.b.blink_pairs = false`
      disabled_filetypes = {},
      -- see the defaults:
      -- https://github.com/Saghen/blink.pairs/blob/main/lua/blink/pairs/config/mappings.lua#L33
      wrap = {}
      pairs = {},
    },
    highlights = {
      enabled = true,
      -- requires require('vim._extui').enable({}), otherwise has no effect
      cmdline = true,
      groups = { 'BlinkPairsOrange', 'BlinkPairsPurple', 'BlinkPairsBlue' },
      unmatched_group = 'BlinkPairsUnmatched',

      -- highlights matching pairs under the cursor
      matchparen = {
        enabled = true,
        -- known issue where typing won't update matchparen highlight, disabled by default
        cmdline = false,
        -- also include pairs not on top of the cursor, but surrounding the cursor
        include_surrounding = false,
        group = 'BlinkPairsMatchParen',
        priority = 250,
      },
    },
    debug = false,
  }
}
```
