-- Run with nvim --headless -u NONE -i NONE -l tests/backspace_overjumps.lua.
-- Requires blink.lib and the native library built for this checkout.
local repo = vim.env.BLINK_PAIRS_TEST_ROOT or vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
local chan = vim.fn.jobstart(
  { vim.v.progpath, '--embed', '--headless', '-u', 'NONE', '-i', 'NONE', '-n' },
  { rpc = true }
)
local function lua(code, ...) return vim.rpcrequest(chan, 'nvim_exec_lua', code, { ... }) end
local function input(keys)
  while keys ~= '' do
    local token = keys:match('^<[^<>]+>') or keys:sub(1, 1)
    keys = keys:sub(#token + 1)
    vim.rpcrequest(chan, 'nvim_input', token == '<' and '<LT>' or token)
    vim.wait(40)
  end
end
local function reset(lines, cursor, ft)
  input('<Esc>')
  lua(
    [[
    local lines, cursor, ft = ...
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buf)
    vim.bo.filetype = ft
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, cursor)
    vim.v.errmsg = ''
  ]],
    lines,
    cursor,
    ft or 'lua'
  )
  input('i')
  lua([[vim.api.nvim_win_set_cursor(0, ...)]], cursor)
end
local function expect(lines, cursor)
  local result =
    lua('return {vim.api.nvim_buf_get_lines(0, 0, -1, false), vim.api.nvim_win_get_cursor(0), vim.v.errmsg}')
  assert(vim.deep_equal(result[1], lines), vim.inspect(result))
  assert(vim.deep_equal(result[2], cursor), vim.inspect(result))
  assert(result[3] == '', vim.inspect(result))
end
local ok, err = pcall(function()
  lua(
    [[
    vim.cmd.packadd('blink.lib')
    vim.opt.rtp:prepend(...)
    require('blink.pairs').setup({ mappings = { cmdline = false }, highlights = { enabled = false } })
    assert(require('blink.pairs.config').mappings.backspace.overjumps == false)
  ]],
    repo
  )
  reset({ '(abc)' }, { 1, 1 })
  input('<BS>')
  expect({ 'abc)' }, { 1, 0 })
  reset({ '()', 'abc', ')' }, { 1, 1 })
  input('<BS>')
  expect({ '', 'abc', ')' }, { 1, 0 })
  print('PASS: disabled by default; existing empty-pair behavior is preserved')

  lua([[require('blink.pairs.config').set({ mappings = { backspace = { overjumps = true } } })]])
  for _, case in ipairs({
    { '(abc)', 1, 'abc', 0 },
    { 'f(abc)tail', 2, 'fabctail', 1 },
    { '((abc))', 1, '(abc)', 0 },
    { '((abc))', 2, '(abc)', 1 },
    { '([abc])', 1, '[abc]', 0 },
    { '{abc}', 1, 'abc', 0 },
    { '[abc]', 1, 'abc', 0 },
    { '"abc"', 1, 'abc', 0 },
    { "'abc'", 1, 'abc', 0 },
    { '(你好🙂)', 1, '你好🙂', 0 },
    { '()', 1, '', 0 },
    { '(  )', 2, '()', 1 },
    { '(abc)', 3, '(ac)', 2 },
    { '(abc', 1, 'abc', 0 },
    { '(abc]', 1, 'abc]', 0 },
    { '\\(abc)', 2, '\\abc)', 1 },
  }) do
    reset({ case[1] }, { 1, case[2] })
    input('<BS>')
    expect({ case[3] }, { 1, case[4] })
  end
  print('PASS: content, nesting, quotes, UTF-8, empty pairs and safe fallback')

  reset({ 'f(', '  abc', ')tail' }, { 1, 2 })
  input('<BS>')
  expect({ 'f', '  abc', 'tail' }, { 1, 1 })
  reset({ '(', '', ')' }, { 1, 1 })
  input('<BS>')
  expect({ '', '', '' }, { 1, 0 })
  reset({ '(', '', ')' }, { 2, 0 })
  input('<BS>')
  expect({ '()' }, { 1, 1 })
  print('PASS: multiline content and existing multiline collapse')

  reset({ '(abc)' }, { 1, 1 })
  input('<BS><Esc>u')
  local lines = lua('return vim.api.nvim_buf_get_lines(0, 0, -1, false)')
  assert(vim.deep_equal(lines, { '(abc)' }), vim.inspect(lines))
  print('PASS: one undo restores both delimiters')

  lua([[
    require('blink.pairs.config').set({ mappings = { pairs = {
      ['('] = { { '(', ')', backspace = false } },
    } } })
  ]])
  reset({ '(abc)' }, { 1, 1 })
  input('<BS>')
  expect({ 'abc)' }, { 1, 0 })
  lua([[
    require('blink.pairs.config').set({ mappings = { pairs = {
      ['('] = { { '(', ')', when = function() return false end } },
    } } })
  ]])
  reset({ '(abc)' }, { 1, 1 })
  input('<BS>')
  expect({ 'abc)' }, { 1, 0 })
  lua([[
    require('blink.pairs.config').set({ mappings = { pairs = {
      ['('] = ')',
      ['"'] = { { '"""', '"""', languages = { 'python' } } },
    } } })
  ]])
  reset({ '"""abc"""' }, { 1, 3 }, 'python')
  input('<BS>')
  expect({ 'abc' }, { 1, 0 })
  print('PASS: per-rule conditions, backspace opt-out and multi-character delimiters')

  reset({ '(abc)' }, { 1, 1 }, 'bigfile')
  input('<BS>')
  expect({ 'abc)' }, { 1, 0 })
  reset({ '(abc)' }, { 1, 1 })
  lua('vim.b.pairs = false')
  input('<BS>')
  expect({ 'abc)' }, { 1, 0 })
  reset({ '(abc)' }, { 1, 1 })
  lua([[require('blink.pairs.config').set({ mappings = { backspace = { overjumps = false } } })]])
  input('<BS>')
  expect({ 'abc)' }, { 1, 0 })
  print('PASS: unsupported filetype, buffer disable and runtime toggle')
end)
vim.fn.jobstop(chan)
assert(ok, err)
print('PASS: backspace overjumps')
