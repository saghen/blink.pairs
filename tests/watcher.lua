-- Run with nvim --headless -u NONE -i NONE -l tests/watcher.lua.
-- Requires blink.lib and the native library built for this checkout.
local repo = vim.env.BLINK_PAIRS_TEST_ROOT or vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
vim.cmd.packadd('blink.lib')
vim.opt.rtp:prepend(repo)

local config = require('blink.pairs.config')
config({ mappings = { cmdline = false }, highlights = { enabled = false } })
local rust = require('blink.pairs.rust')
local watcher = require('blink.pairs.watcher')
local original_get_lines = vim.api.nvim_buf_get_lines
local reads = {}
vim.api.nvim_buf_get_lines = function(bufnr, start, stop, strict)
  reads[bufnr] = (reads[bufnr] or 0) + 1
  return original_get_lines(bufnr, start, stop, strict)
end
local function buffer(ft)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '()' })
  vim.bo[buf].filetype = ft
  return buf
end
local ok, err = pcall(function()
  for _, ft in ipairs({ 'bigfile', 'blink_pairs_unsupported' }) do
    local buf = buffer(ft)
    for _ = 1, 3 do
      assert(watcher.attach(buf) == false)
    end
    assert(reads[buf] == nil, 'unsupported filetype read buffer contents: ' .. ft)
    assert(watcher.watched_bufnrs[buf] == nil)
  end
  vim.treesitter.language.register('blink_pairs_unsupported', 'blink_pairs_unsupported_alias')
  local unsupported_alias = buffer('blink_pairs_unsupported_alias')
  assert(watcher.attach(unsupported_alias) == false)
  assert(reads[unsupported_alias] == nil, 'unsupported treesitter alias read buffer contents')
  print('PASS: repeated attach of unsupported filetypes never reads the buffer')

  local buf = buffer('bigfile')
  assert(watcher.attach(buf) == false)
  vim.bo[buf].filetype = 'lua'
  assert(watcher.attach(buf) == true)
  assert(reads[buf] == 1)
  assert(#rust.get_line_matches(buf, 0) == 2)
  assert(watcher.attach(buf) == true)
  assert(reads[buf] == 1, 'already attached buffer was read again')
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { '(())' })
  assert(#rust.get_line_matches(buf, 0) == 4, 'incremental parsing stopped working')
  local reads_before = reads[buf]
  vim.bo[buf].filetype = 'bigfile'
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { '()' })
  assert(reads[buf] == reads_before, 'unsupported incremental update read buffer contents')
  assert(watcher.watched_bufnrs[buf] == nil)
  print('PASS: filetype changes, cached attach and incremental parsing')

  vim.treesitter.language.register('lua', 'blink_pairs_lua_alias')
  local alias = buffer('blink_pairs_lua_alias')
  assert(watcher.attach(alias) == true)
  assert(reads[alias] == 1)
  assert(#rust.get_line_matches(alias, 0) == 2)
  local cmd = buffer('cmd')
  assert(watcher.attach(cmd) == true)
  assert(#rust.get_line_matches(cmd, 0) == 2)
  print('PASS: supported treesitter aliases and command-line filetype mapping')
end)
vim.api.nvim_buf_get_lines = original_get_lines
assert(ok, err)
print('PASS: watcher filetype guard')
