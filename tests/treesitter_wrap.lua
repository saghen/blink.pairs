-- Run with nvim --headless -u NONE -i NONE -l tests/treesitter_wrap.lua.
-- Requires blink.lib, the native library built for this checkout, and the Lua parser.
local repo = vim.env.BLINK_PAIRS_TEST_ROOT or vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
local overlay = vim.env.BLINK_PAIRS_TEST_OVERLAY
local chan = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', 'NONE', '-i', 'NONE', '-n' }, {
  rpc = true,
})
local function lua(code, ...) return vim.rpcrequest(chan, 'nvim_exec_lua', code, { ... }) end
local function input(keys)
  while keys ~= '' do
    local token = keys:match('^<[^<>]+>') or keys:sub(1, 1)
    keys = keys:sub(#token + 1)
    vim.rpcrequest(chan, 'nvim_input', token == '<' and '<LT>' or token)
    vim.wait(40)
  end
end
local function reset(text, col, ft)
  input('<Esc>')
  lua(
    [[
    local text, col, ft = ...
    local b = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(b)
    vim.bo.filetype = ft or 'lua'
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { text })
    vim.api.nvim_win_set_cursor(0, { 1, col })
    vim.v.errmsg = ''
  ]],
    text,
    col,
    ft or 'lua'
  )
  input('i')
end
local function expect(text, col)
  local result = lua('return {vim.api.nvim_get_current_line(),vim.api.nvim_win_get_cursor(0)[2],vim.v.errmsg}')
  assert(result[1] == text and (col == nil or result[2] == col) and result[3] == '', vim.inspect(result))
end
local ok, err = pcall(function()
  lua(
    [[
    local repo, overlay = ...
    vim.cmd.packadd('blink.lib')
    vim.opt.rtp:prepend(repo)
    if overlay then vim.opt.rtp:prepend(overlay) end
    require('blink.pairs').setup({ mappings = { cmdline = false }, highlights = { enabled = false } })
    local wrap = require('blink.pairs.mappings.wrap')
    wrap.register_treesitter('<M-e>', 'fwd')
    wrap.register_treesitter('<M-E>', 'rev')
  ]],
    repo,
    overlay
  )
  for _, col in ipairs({ 0, 2, 4, 5 }) do
    reset('good()a', col)
    input('<M-e>')
    expect('good(a)', 6)
    input('<M-E>')
    expect('good()a', 5)
    input('<M-E>')
    expect('good()a', 5)
  end
  print('PASS: good()a from function name and brackets, forward and reverse')
  reset('good()alpha + beta', 2)
  local snapshots = { 'good()alpha + beta' }
  for _ = 1, 3 do
    input('<M-e>')
    local text = lua('return vim.api.nvim_get_current_line()')
    if text ~= snapshots[#snapshots] then snapshots[#snapshots + 1] = text end
  end
  print('forward cycle:', vim.inspect(snapshots))
  assert(#snapshots >= 3)
  for i = #snapshots - 1, 1, -1 do
    input('<M-E>')
    expect(snapshots[i])
  end
  print('PASS: repeated forward and reverse steps')
  reset('good()a', 2)
  input('<M-e><Esc>u')
  expect('good()a')
  print('PASS: one undo restores the complete move')
  for _, case in ipairs({ { 'good()', 2 }, { 'good', 2 }, { 'good(a', 2 } }) do
    reset(case[1], case[2])
    input('<M-e><M-E>')
    expect(case[1], case[2])
  end
  reset('good()a', 2, 'bigfile')
  input('<M-e><M-E>')
  expect('good()a', 2)
  print('PASS: no target, unmatched bracket and unsupported filetype stay unchanged')
  reset('good()a', 2)
  lua('vim.b.pairs=false')
  lua([[require('blink.pairs.mappings.wrap.treesitter').wrap('fwd')]])
  expect('good()a', 2)
  reset('good()a', 2)
  input('<M-e><Left>')
  local before = lua('return vim.api.nvim_get_current_line()')
  input('<M-E>')
  expect(before)
  reset('good()a', 2)
  input('<M-e>x')
  before = lua('return vim.api.nvim_get_current_line()')
  input('<M-E>')
  expect(before)
  print('PASS: cursor movement and edits invalidate previous cycle')
  reset('""abc', 0)
  input('<M-e>')
  expect('"abc"', 4)
  input('<M-E>')
  expect('""abc', 1)
  reset('good()你好', 2)
  input('<M-e>')
  expect('good(你好)', 11)
  input('<M-E>')
  expect('good()你好', 5)
  print('PASS: quotes and UTF-8 text')
  reset('good()a -- ignored', 2)
  input('<M-e>')
  expect('good(a) -- ignored', 6)
  input('<M-e>')
  expect('good(a) -- ignored', 6)
  input('<M-E>')
  expect('good()a -- ignored', 5)
  reset('good() -- ignored', 2)
  input('<M-e>')
  expect('good() -- ignored', 2)
  print('PASS: comments are not wrap targets')
  reset('good()a', 2)
  input('<M-e>x<Esc>')
  lua(
    [[vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'good()alpha + beta' }); vim.api.nvim_win_set_cursor(0, { 1, 2 })]]
  )
  input('i<M-e>')
  expect('good(alpha) + beta', 10)
  print('PASS: refresh syntax tree after edits')
  reset('', 0)
  input('()')
  expect('()', 2)
  print('PASS: ordinary pair completion')
end)
vim.fn.jobstop(chan)
assert(ok, err)
print('PASS: Fastwarp integration')
