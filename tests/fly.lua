-- Run with nvim --headless -u NONE -i NONE -l tests/fly.lua.
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
    vim.wait(15)
  end
end
local function reset(lines, cursor, ft)
  input('<Esc>')
  lua(
    [[
    local lines, cursor, ft = ...
    local b = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(b)
    vim.bo.filetype = ft
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, cursor)
    require('blink.pairs.watcher').attach(b)
    vim.v.errmsg = ''
  ]],
    lines,
    cursor,
    ft
  )
  input('i')
  lua([[vim.api.nvim_win_set_cursor(0, ...)]], cursor)
end
local function expect(lines, cursor)
  local result =
    lua('return {vim.api.nvim_buf_get_lines(0, 0, -1, false), vim.api.nvim_win_get_cursor(0), vim.v.errmsg}')
  assert(
    vim.deep_equal(result[1], lines) and vim.deep_equal(result[2], cursor) and result[3] == '',
    vim.inspect(result)
  )
end
local ok, err = pcall(function()
  lua(
    [[
    vim.cmd.packadd('blink.lib')
    vim.opt.rtp:prepend(...)
    require('blink.pairs').setup({ mappings = { cmdline = false }, highlights = { enabled = false } })
    assert(require('blink.pairs.config').mappings.fly.enabled == false)
  ]],
    repo
  )

  reset({ '([])' }, { 1, 2 }, 'lua')
  input(')')
  expect({ '([)])' }, { 1, 3 })
  lua([[require('blink.pairs.config').set({mappings={fly={enabled=true}}})]])
  for _, case in ipairs({
    { '([])', 2, ')', 4 },
    { '({[]})', 3, ')', 6 },
    { '({[]})', 3, '}', 5 },
    { '([ ])', 2, ')', 5 },
    { '([]  )tail', 2, ')', 6 },
    { '([{}])', 2, ')', 6 },
    { '( [] )', 1, ')', 6 },
    { '([])', 2, ']', 3 },
  }) do
    reset({ case[1] }, { 1, case[2] }, 'lua')
    input(case[3])
    expect({ case[1] }, { 1, case[4] })
  end
  for _, case in ipairs({
    { '([abc])', 2, ')', '([)abc])', 3 },
    { '([]foo)', 2, ')', '([)]foo)', 3 },
    { '([,])', 2, ')', '([),])', 3 },
    { '(["abc"])', 2, ')', '([)"abc"])', 3 },
    { '([)]', 2, ')', '([)]', 3 },
    { '([])', 2, '}', '([}])', 3 },
  }) do
    reset({ case[1] }, { 1, case[2] }, 'lua')
    input(case[3])
    expect({ case[4] }, { 1, case[5] })
  end
  reset({ '([', '])' }, { 1, 2 }, 'lua')
  input(')')
  expect({ '([)', '])' }, { 1, 3 })
  reset({ '([])' }, { 1, 2 }, 'bigfile')
  input(')')
  expect({ '([)])' }, { 1, 3 })
  reset({ '(()' }, { 1, 2 }, 'lua')
  input(')')
  expect({ '(())' }, { 1, 3 })
  reset({ '([])' }, { 1, 2 }, 'lua')
  lua('vim.b.pairs = false')
  input(')')
  expect({ '([)])' }, { 1, 3 })
  lua([[require('blink.pairs.config').set({mappings={pairs={['(']={{'(',')',close=false}}}}})]])
  lua([[require('blink.pairs.mappings').enable()]])
  reset({ '([])' }, { 1, 2 }, 'lua')
  input(')')
  expect({ '([)])' }, { 1, 3 })
  lua([[require('blink.pairs.config').set({mappings={pairs={['(']=')'}}})]])
  lua([[require('blink.pairs.mappings').enable()]])
  lua([[require('blink.pairs.config').set({mappings={fly={enabled=false}}})]])
  reset({ '([])' }, { 1, 2 }, 'lua')
  input(')')
  expect({ '([)])' }, { 1, 3 })
  print('PASS: fly defaults, nested brackets, whitespace, runtime toggle and safe boundaries')
end)
vim.fn.jobstop(chan)
assert(ok, err)
print('PASS: fly')
