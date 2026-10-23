-- Run with nvim --headless -u NONE -i NONE -l tests/comment_closing.lua.
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

  for _, ft in ipairs({ 'html', 'markdown' }) do
    for _, text in ipairs({ '<!---->', '<!-- text -->', '<!--hello-->' }) do
      local closing = assert(text:find('-->', 5, true)) - 1
      reset({ text }, { 1, closing }, ft)
      input('-')
      expect({ text }, { 1, #text })
    end
    reset({ '<!--hello -->' }, { 1, 9 }, ft)
    input('-')
    expect({ '<!--hello -->' }, { 1, 13 })
    reset({ '<!--hello -->tail' }, { 1, 10 }, ft)
    input('-')
    expect({ '<!--hello -->tail' }, { 1, 13 })
    reset({ '<!--', 'hello', '-->' }, { 3, 0 }, ft)
    input('-')
    expect({ '<!--', 'hello', '-->' }, { 3, 3 })
    reset({ '<!-- hello', 'end -->' }, { 2, 4 }, ft)
    input('-')
    expect({ '<!-- hello', 'end -->' }, { 2, 7 })
    reset({ '-->' }, { 1, 0 }, ft)
    input('-')
    expect({ '--->' }, { 1, 1 })
    reset({ '<!--done--> -->' }, { 1, 12 }, ft)
    input('-')
    expect({ '<!--done--> --->' }, { 1, 13 })
    reset({ '' }, { 1, 0 }, ft)
    input('<!hello-')
    expect({ '<!--hello-->' }, { 1, 12 })
  end
  reset({ '<!--hello-->' }, { 1, 9 }, 'lua')
  input('-')
  expect({ '<!--hello--->' }, { 1, 10 })
  print('PASS: comment closing with content, empty and multiline comments, unrelated hyphens')

  reset({ '' }, { 1, 0 }, 'rust')
  input('"')
  expect({ '""' }, { 1, 1 })
  reset({ 'r#' }, { 1, 2 }, 'rust')
  input('"content"')
  expect({ 'r#"content"#' }, { 1, 12 })
end)
vim.fn.jobstop(chan)
assert(ok, err)
print('PASS: comment_closing')
