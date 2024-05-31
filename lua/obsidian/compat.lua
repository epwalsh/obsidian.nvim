local compat = {}

compat.is_list = function(t)
  if vim.fn.has "nvim-0.11" == 1 then
    return vim.islist(t)
  else
    return vim.tbl_islist(t)
  end
end

compat.flatten = function(t)
  if vim.fn.has "nvim-0.11" == 1 then
    return vim.iter(t):flatten():totable()
  else
    return vim.tbl_flatten(t)
  end
end

return compat
