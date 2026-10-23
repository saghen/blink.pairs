-- Run with nvim --headless -u NONE -i NONE -l tests/python_string_prefixes.lua.
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
  ]],
    repo
  )

  for _, prefix in ipairs({
    'f',
    'r',
    'b',
    'u',
    'fr',
    'rf',
    'br',
    'rb',
    't',
    'tr',
    'rt',
    'F',
    'R',
    'B',
    'U',
    'Fr',
    'rF',
    'BR',
    'Rb',
    'T',
    'Tr',
    'rT',
  }) do
    for _, quote in ipairs({ "'", '"' }) do
      local text = 'x = ' .. prefix
      reset({ text }, { 1, #text }, 'python')
      input(quote)
      expect({ text .. quote .. quote }, { 1, #text + 1 })
    end
  end
  for _, prefix in ipairs({ 'foo', 'ff', 'bf', 'ur', 'rr', 'abr', 'identifier_f', '你好f' }) do
    local text = 'x = ' .. prefix
    reset({ text }, { 1, #text }, 'python')
    input("'")
    expect({ text .. "'" }, { 1, #text + 1 })
  end
  reset({ 'x = f' }, { 1, 5 }, 'lua')
  input("'")
  expect({ "x = f'" }, { 1, 6 })
  reset({ 'x = rf' }, { 1, 6 }, 'python')
  input("'content'")
  expect({ "x = rf'content'" }, { 1, 15 })
  reset({ 'x = f' }, { 1, 5 }, 'python')
  input("'{value}'")
  expect({ "x = f'{value}'" }, { 1, 14 })
  for _, prefix in ipairs({ 'f', 'r', 'b', 'u', 'fr', 'rf', 'br', 'rb' }) do
    for _, quote in ipairs({ "'", '"' }) do
      local text = 'x = ' .. prefix
      reset({ text }, { 1, #text }, 'python')
      input(quote .. quote .. quote)
      expect({ text .. string.rep(quote, 6) }, { 1, #text + 3 })
    end
  end
  print('PASS: valid case-insensitive Python prefixes, invalid identifier boundaries and closing skip')
end)
vim.fn.jobstop(chan)
assert(ok, err)
print('PASS: python_string_prefixes')
