local nvim = require('blink.lib.nvim')

local M = {}

--- @param config blink.pairs.HighlightsConfig
function M.setup(config)
  if not (config.matchparen and config.matchparen.enabled) then return end

  local rust = require('blink.pairs.rust')
  local mappings_config = require('blink.pairs.config').mappings
  local ns = nvim.create_namespace('blink_pairs_matchparen')
  local last_buf
  local enabled, include_surrounding = config.matchparen.enabled, config.matchparen.include_surrounding
  -- `true` enables every token type
  local token_types = enabled ~= true and enabled or nil
  -- `true` includes the same token types as `enabled`
  local surrounding_token_types = include_surrounding ~= true and include_surrounding or token_types

  --- @type vim.api.keyset.events[]
  local autocmds = { 'CursorMoved', 'CursorMovedI' }
  if vim.fn.exists('##CursorMovedC') == 1 and config.cmdline then table.insert(autocmds, 'CursorMovedC') end

  nvim.create_autocmd(autocmds, {
    group = nvim.create_augroup('BlinkPairsMatchparen', {}),
    callback = function(ev)
      if
        vim.b.pairs == false
        or vim.b.blink_pairs == false
        or vim.tbl_contains(mappings_config.disabled_filetypes, vim.bo.filetype)
      then
        return
      end

      local mode = nvim.get_mode().mode
      -- In insert mode, we'll get the CursorMovedI event, so we can ignore CursorMoved
      if
        (mode:match('i') and ev.event ~= 'CursorMovedI')
        or (mode:match('c') and config.cmdline and ev.event ~= 'CursorMovedC')
      then
        return
      end

      -- TODO: run this for all the windows
      local ctx = require('blink.pairs.context').new()
      -- prompt mark (`:`, `/`) is not considered when do parsing
      local prompt_len = (mode:match('c') and 1 or 0)
      local cursor = { ctx.cursor.row, ctx.cursor.col + prompt_len }
      local buf = ctx.bufnr
      -- TODO: returns nil in cmdline mode due to the autocmd running before the watcher
      local pair = rust.get_match_pair(buf, cursor[1] - 1, cursor[2], token_types)
      if pair == nil and include_surrounding then
        pair = rust.get_surrounding_match_pair(buf, cursor[1] - 1, cursor[2], nil, surrounding_token_types)
      end

      -- Clear extmarks
      if last_buf and nvim.buf_is_valid(last_buf) then nvim.buf_clear_namespace(last_buf, ns, 0, -1) end
      last_buf = buf

      if pair == nil then return end

      -- Highlight matches
      for i, match in ipairs(pair) do
        nvim.buf_set_extmark(buf, ns, match.line, match.col, {
          end_col = match.col + (match[i] or match[1]):len(),
          hl_group = config.matchparen.group,
          hl_mode = 'combine',
          priority = config.matchparen.priority,
        })
      end
    end,
  })
end

return M
