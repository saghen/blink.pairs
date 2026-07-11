local function set_highlights()
  vim.api.nvim_set_hl(0, 'BlinkPairsOrange', { ctermfg = 15, fg = '#d65d0e', default = true })
  vim.api.nvim_set_hl(0, 'BlinkPairsPurple', { ctermfg = 13, fg = '#b16286', default = true })
  vim.api.nvim_set_hl(0, 'BlinkPairsBlue', { ctermfg = 12, fg = '#458588', default = true })
  vim.api.nvim_set_hl(0, 'BlinkPairsUnmatched', { ctermfg = 9, fg = '#ff007c', default = true })
  vim.api.nvim_set_hl(0, 'BlinkPairsMatchParen', { link = 'MatchParen', default = true })
end

set_highlights()
vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('blink_pairs_highlights', {}),
  callback = set_highlights,
})
