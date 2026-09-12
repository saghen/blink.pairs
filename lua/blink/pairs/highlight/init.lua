local nvim = require('blink.lib.nvim')

local highlighter = {}
local ns = nvim.create_namespace('blink.pairs')
--- Lines with up to date extmarks
--- @type table<number, table<number, boolean>>
local rendered = {}

--- Clears and redraws the highlights of the lines whose matches changed
--- @param bufnr number
--- @param start_line number
--- @param end_line? number Defaults to the end of the buffer
function highlighter.invalidate(bufnr, start_line, end_line)
  local lines = rendered[bufnr]
  -- large ranges cover the viewport anyway, so skip the per-line bookkeeping
  if end_line == nil or end_line - start_line > 1000 then
    nvim.buf_clear_namespace(bufnr, ns, 0, -1)
    rendered[bufnr] = nil
  else
    nvim.buf_clear_namespace(bufnr, ns, start_line, end_line)
    for line = start_line, end_line - 1 do
      if lines then lines[line] = nil end
    end
  end
  -- nvim only redraws lines whose text or extmarks changed, so request the rest
  local range = { start_line, end_line or nvim.buf_line_count(bufnr) }
  vim.api.nvim__redraw({ buf = bufnr, range = range, flush = false })
end

--- @param config blink.pairs.HighlightsConfig
function highlighter.register(config)
  --- @type fun(match: blink.pairs.Match): string
  --- @diagnostic disable-next-line: assign-type-mismatch
  local get_match_highlight = type(config.groups) == 'function' and config.groups
    or function(match) return config.groups[match.pair_depth % #config.groups + 1] end

  local watcher = require('blink.pairs.watcher')
  local get_line_matches = require('blink.pairs.rust').get_line_matches
  local mappings_config = require('blink.pairs.config').mappings

  local cmdline_enabled = config.cmdline

  nvim.create_autocmd('BufWipeout', { callback = function(ev) rendered[ev.buf] = nil end })

  nvim.set_decoration_provider(ns, {
    on_win = function(_, _, bufnr)
      if
        vim.b[bufnr].pairs == false
        or vim.b[bufnr].blink_pairs == false
        or vim.tbl_contains(mappings_config.disabled_filetypes, vim.bo[bufnr].filetype)
      then
        return false
      end

      local is_cmdline = nvim.get_mode().mode:match('c')
      if is_cmdline then
        local is_cmdline_extui_buf = vim.bo[bufnr].filetype == 'cmd'
        if is_cmdline_extui_buf then
          if not cmdline_enabled then return false end
        else
          -- non-extui buf in cmdline mode (:substitute etc.) — parse state is stale
          return false
        end
      end

      -- start parsing, skip if unsupported
      if not watcher.attach(bufnr) then return false end

      -- skip colorization if no groups defined, but keep watcher attached for matchparen
      return not (type(config.groups) == 'table' and #config.groups == 0)
    end,

    on_line = function(_, _, bufnr, line_number)
      local lines = rendered[bufnr]
      if not lines then
        lines = {}
        rendered[bufnr] = lines
      end
      if lines[line_number] then return end
      lines[line_number] = true

      local matches = get_line_matches(bufnr, line_number)
      for i = 1, #matches do
        local match = matches[i]
        nvim.buf_set_extmark(bufnr, ns, line_number, match.col, {
          end_col = match.col + match[1]:len(),
          hl_group = match.depth == nil and config.unmatched_group or get_match_highlight(match),
          hl_mode = 'combine',
          priority = config.priority,
        })
      end
    end,
  })

  if config.matchparen and config.matchparen.enabled then require('blink.pairs.highlight.matchparen').setup(config) end
end

return highlighter
