local utils = {}

function utils.get_tab_width(bufnr)
  local shiftwidth = vim.api.nvim_get_option_value('shiftwidth', { buf = bufnr })
  -- todo: is this correct?
  if shiftwidth == 0 then shiftwidth = vim.api.nvim_get_option_value('tabstop', { buf = bufnr }) end
  -- default to 2 if shiftwidth and tabwidth are 0
  return math.max(shiftwidth, 2)
end

--- Finds the maximum overlap between two strings (a and b)
--- from the end of "a" and beginning of "b"
--- @param a string
--- @param b string
--- @return number
function utils.find_overlap(a, b)
  for overlap = math.min(#a, #b), 1, -1 do
    if a:sub(-overlap) == b:sub(1, overlap) then return overlap end
  end
  return 0
end

--- TODO: Apparently there can be flicker in large files with treesitter enabled
--- Need to investigate this
--- @generic T
--- @param f fun(): T
--- @return T
function utils.with_lazyredraw(f)
  local lazyredraw = vim.o.lazyredraw
  vim.o.lazyredraw = true

  local success, result_or_err = pcall(f)

  vim.o.lazyredraw = lazyredraw

  if not success then error(result_or_err) end
  return result_or_err
end

return utils
