---@param client obsidian.Client
return function(client, data)
  local opts = {}
  if data.args and string.len(data.args) > 0 then
    opts.open_strategy = data.args
  end
  vim.cmd [[normal! m']]
  client:follow_link_async(nil, opts)
end
