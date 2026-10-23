-- Run with nvim --headless -u NONE -i NONE -l tests/triple_quote_closing.lua.
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
    vim.bo.filetype = ft or 'python'
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, cursor)
    vim.v.errmsg = ''
  ]],
    lines,
    cursor,
    ft or 'python'
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
  for _, quote in ipairs({ "'", '"' }) do
    for _, prefix in ipairs({ '', 'f', 'r', 'b', 'u', 'fr', 'rf', 'br', 'rb', 'F', 'rF', 't', 'tr', 'rt' }) do
      local before = 'x = ' .. prefix
      reset({ before }, { 1, #before })
      input(string.rep(quote, 3))
      expect({ before .. string.rep(quote, 6) }, { 1, #before + 3 })
      input(quote)
      expect({ before .. string.rep(quote, 6) }, { 1, #before + 6 })
      reset({ before }, { 1, #before })
      input(string.rep(quote, 3) .. 'content' .. quote)
      expect({ before .. string.rep(quote, 3) .. 'content' .. string.rep(quote, 3) }, { 1, #before + 13 })
    end
    reset({ string.rep(quote, 6) .. 'tail' }, { 1, 3 })
    input(quote)
    expect({ string.rep(quote, 6) .. 'tail' }, { 1, 6 })
    reset({ string.rep(quote, 3), 'content', string.rep(quote, 3) }, { 3, 0 })
    input(quote)
    expect({ string.rep(quote, 3), 'content', string.rep(quote, 3) }, { 3, 3 })
    reset({ string.rep(quote, 3), 'content' .. string.rep(quote, 3) }, { 2, 7 })
    input(quote)
    expect({ string.rep(quote, 3), 'content' .. string.rep(quote, 3) }, { 2, 10 })
    reset({ '' }, { 1, 0 })
    input(quote .. 'content' .. quote)
    expect({ quote .. 'content' .. quote }, { 1, 9 })
    reset({ '' }, { 1, 0 })
    input(string.rep(quote, 3) .. '\\' .. quote)
    expect({ string.rep(quote, 3) .. '\\' .. string.rep(quote, 4) }, { 1, 5 })
    reset({ '' }, { 1, 0 })
    input(string.rep(quote, 3) .. '<BS>')
    expect({ '' }, { 1, 0 })
  end
  print('PASS: Python empty, prefixed, non-empty and multiline triple-string closing; escapes and backspace')
  for _, item in ipairs({ { 'toml', "'" }, { 'toml', '"' }, { 'julia', '"' } }) do
    reset({ '' }, { 1, 0 }, item[1])
    input(string.rep(item[2], 3))
    expect({ string.rep(item[2], 6) }, { 1, 3 })
    input(item[2])
    expect({ string.rep(item[2], 6) }, { 1, 6 })
  end
  print('PASS: shared triple-quote rules in TOML and Julia')
end)
vim.fn.jobstop(chan)
assert(ok, err)
print('PASS: triple-quote closing')
