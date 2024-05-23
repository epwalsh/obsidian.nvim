local compat = {}

compat.is_list = vim.islist or vim.tbl_islist

compat.flatten = function(t)
  if vim.fn.has "nvim-0.11" == 1 then
    return vim.iter(t):flatten():totable()
  else
    return vim.tbl_flatten(t)
  end
end

return compat
