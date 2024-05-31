local compat = {}

local has_nvim_0_11 = false
if vim.fn.has "nvim-0.11" == 1 then
  has_nvim_0_11 = true
end

compat.is_list = function(t)
  if has_nvim_0_11 then
    return vim.islist(t)
  else
    return vim.tbl_islist(t)
  end
end

compat.flatten = function(t)
  if has_nvim_0_11 then
    ---@diagnostic disable-next-line: undefined-field
    return vim.iter(t):flatten():totable()
  else
    return vim.tbl_flatten(t)
  end
end

return compat
