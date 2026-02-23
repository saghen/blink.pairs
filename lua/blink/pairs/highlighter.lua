local nvim_buf_set_extmark = vim.api.nvim_buf_set_extmark
local nvim_buf_clear_namespace = vim.api.nvim_buf_clear_namespace
local nvim_buf_get_changedtick = vim.api.nvim_buf_get_changedtick
local nvim_get_mode = vim.api.nvim_get_mode

local highlighter = {}

--- @param config blink.pairs.HighlightsConfig
function highlighter.register(config)
  --- @type fun(match: blink.pairs.Match): string
  --- @diagnostic disable-next-line: assign-type-mismatch
  local get_match_highlight = type(config.groups) == 'function' and config.groups
    or function(match) return config.groups[match.stack_height % #config.groups + 1] end

  local watcher_attach = require('blink.pairs.watcher').attach
  local get_line_matches = require('blink.pairs.rust').get_line_matches

  local ns = config.ns
  local cmdline_enabled = config.cmdline

  -- Per-buffer state: tracks which lines have persistent extmarks
  local buf_ticks = {} -- bufnr -> changedtick at last full render
  local buf_rendered = {} -- bufnr -> { [line_number] = true }

  -- Per-window viewport: skip on_line entirely when viewport hasn't moved
  local win_view = {} -- winid -> { bufnr, tick, toprow, botrow }

  vim.api.nvim_create_autocmd('BufWipeout', {
    callback = function(ev)
      buf_ticks[ev.buf] = nil
      buf_rendered[ev.buf] = nil
    end,
  })

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, winnr, bufnr, toprow, botrow)
      local is_cmdline = nvim_get_mode().mode:match('c')
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
      if not watcher_attach(bufnr) then return false end

      -- buffer changed, full redraw
      local tick = nvim_buf_get_changedtick(bufnr)
      if tick ~= buf_ticks[bufnr] then
        nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        buf_ticks[bufnr] = tick
        buf_rendered[bufnr] = {}
        win_view[winnr] = { bufnr, tick, toprow, botrow }
        return true
      end

      -- if viewport didnt change, skip drawing
      local wv = win_view[winnr]
      if wv and wv[1] == bufnr and wv[2] == tick and wv[3] == toprow and wv[4] == botrow then return false end

      -- partial redraw with new viewport
      win_view[winnr] = { bufnr, tick, toprow, botrow }
      return true
    end,

    on_line = function(_, _, bufnr, line_number)
      local rendered = buf_rendered[bufnr]
      if rendered and rendered[line_number] then return end

      if not rendered then
        rendered = {}
        buf_rendered[bufnr] = rendered
      end
      rendered[line_number] = true

      local matches = get_line_matches(bufnr, line_number)
      for i = 1, #matches do
        local match = matches[i]
        nvim_buf_set_extmark(bufnr, ns, line_number, match.col, {
          end_col = match.col + match[1]:len(),
          hl_group = match.stack_height == nil and config.unmatched_group or get_match_highlight(match),
          hl_mode = 'combine',
          priority = config.priority,
        })
      end
    end,
  })

  if config.matchparen.enabled then require('blink.pairs.matchparen').setup(config) end
end

return highlighter
