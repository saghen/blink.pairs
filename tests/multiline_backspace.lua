-- Run with nvim --headless -u NONE -i NONE -l tests/multiline_backspace.lua.
-- Requires blink.lib and the native library built for this checkout.
local repo = vim.env.BLINK_PAIRS_TEST_ROOT or vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
local chan = vim.fn.jobstart(
  { vim.v.progpath, '--embed', '--headless', '-u', 'NONE', '-i', 'NONE', '-n' },
  { rpc = true }
)
local function lua(code, ...) return vim.rpcrequest(chan, 'nvim_exec_lua', code, { ... }) end
local function input(keys)
  while keys ~= '' do
    local key = keys:match('^<[^<>]+>') or keys:sub(1, 1)
    keys = keys:sub(#key + 1)
    vim.rpcrequest(chan, 'nvim_input', key)
    vim.wait(20)
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
    vim.bo.autoindent = true
    vim.bo.expandtab = true
    vim.bo.softtabstop = 0
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
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
    require('blink.pairs').setup({mappings={cmdline=false},highlights={enabled=false}})
  ]],
    repo
  )
  reset({ '{', '    ', '}' }, { 2, 4 })
  input('<BS>')
  expect({ '{}' }, { 1, 1 })
  for _, case in ipairs({
    { { '{', '', '}' }, { 2, 0 }, { '{}' }, { 1, 1 } },
    { { '{', '\t', '}' }, { 2, 1 }, { '{}' }, { 1, 1 } },
    { { '    {', '        ', '    }' }, { 2, 8 }, { '    {}' }, { 1, 5 } },
    { { '\t{', '\t\t', '\t}' }, { 2, 2 }, { '\t{}' }, { 1, 2 } },
    { { 'f(', '  \t  ', '  )' }, { 2, 2 }, { 'f()' }, { 1, 2 } },
    { { '[', '    ', ']  ' }, { 2, 0 }, { '[]  ' }, { 1, 1 } },
  }) do
    reset(case[1], case[2])
    input('<BS>')
    expect(case[3], case[4])
  end
  reset({ '{', '    ', '}' }, { 2, 4 }, 'bigfile')
  input('<BS>')
  expect({ '{}' }, { 1, 1 })
  print('PASS: empty and indented middle lines, tabs, cursor positions and bigfile')

  for _, pair in ipairs({ '{}', '()', '[]' }) do
    reset({ '    ' .. pair }, { 1, 5 })
    input('<CR>')
    local expanded = lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)')
    assert(#expanded == 3 and expanded[2]:match('^%s*$'), vim.inspect(expanded))
    input('<BS>')
    expect({ '    ' .. pair }, { 1, 5 })
  end
  print('PASS: Enter expansion followed by one backspace restores the pair')

  reset({ '{', '    ', '}' }, { 2, 4 })
  input('<C-g>u<BS><Esc>u')
  local restored = lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)')
  assert(vim.deep_equal(restored, { '{', '    ', '}' }), vim.inspect(restored))
  print('PASS: one undo restores the complete expanded layout')

  reset({ '{', '    x', '}' }, { 2, 5 })
  input('<BS>')
  expect({ '{', '    ', '}' }, { 2, 4 })
  reset({ '{', '    ', '}tail' }, { 2, 4 })
  input('<BS>')
  expect({ '{', '', '}tail' }, { 2, 0 })
  reset({ '{', '    ', ')' }, { 2, 4 })
  input('<BS>')
  expect({ '{', '', ')' }, { 2, 0 })
  reset({ '{', '    ', '}' }, { 2, 4 })
  lua('vim.b.pairs = false')
  input('<BS>')
  expect({ '{', '', '}' }, { 2, 0 })
  lua([[require('blink.pairs.config').set({mappings={pairs={['{']={{'{','}',backspace=false}}}}})]])
  lua([[require('blink.pairs.mappings').enable()]])
  reset({ '{', '    ', '}' }, { 2, 4 })
  input('<BS>')
  expect({ '{', '', '}' }, { 2, 0 })
  print('PASS: contents, mismatched closing, suffix and backspace opt-out are preserved')
end)
vim.fn.jobstop(chan)
assert(ok, err)
print('PASS: multiline backspace')
