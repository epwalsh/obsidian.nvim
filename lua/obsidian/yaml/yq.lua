local m = {}

---@param str string
---@return any
m.loads = function(str)
  local as_json = vim.fn.system("yq -o=json", str)
  local data = vim.json.decode(as_json, { luanil = { object = true, array = true } })
  return data
end

return m
