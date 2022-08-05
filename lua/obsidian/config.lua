local config = {}

---[[ Options specs ]]---

---@class obsidian.config.ClientOpts
---@field dir string
---@field completion obsidian.config.CompletionOpts
config.ClientOpts = {}

---Get defaults.
---@return obsidian.config.ClientOpts
config.ClientOpts.default = function()
  return {
    dir = vim.fs.normalize "./",
    completion = config.CompletionOpts.default(),
  }
end

---Normalize options.
---
---@param opts table<string, any>
---@return obsidian.config.ClientOpts
config.ClientOpts.normalize = function(opts)
  opts = vim.tbl_extend("force", config.ClientOpts.default(), opts)
  opts.completion = vim.tbl_extend("force", config.CompletionOpts.default(), opts.completion)
  return opts
end

---@class obsidian.config.CompletionOpts
---@field nvim_cmp boolean
---@field min_chars integer
config.CompletionOpts = {}

---Get defaults.
---@return obsidian.config.CompletionOpts
config.CompletionOpts.default = function()
  local has_nvim_cmp, _ = pcall(require, "cmp")
  return {
    nvim_cmp = has_nvim_cmp,
    min_chars = 2,
  }
end

return config
