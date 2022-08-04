local Path = require "plenary.path"

local obsidian = {}

obsidian.completion = require "obsidian.completion"
obsidian.note = require "obsidian.note"
obsidian.util = require "obsidian.util"

--[[
-- Options classes:
--]]

---@class obsidian.Opts
---@field dir string
---@field completion obsidian.CompletionOpts

---@class obsidian.CompletionOpts
---@field nvim_cmp boolean

---@class obsidian.Client
---@field dir Path
local client = {}

---Create a new Obsidian client without additional setup.
---
---@param dir string
---@return obsidian.Client
obsidian.new = function(dir)
  local self = setmetatable({}, { __index = client })
  self.dir = Path:new(vim.fs.normalize(dir and dir or "./"))
  return self
end

---Setup a new Obsidian client.
---
---@param opts obsidian.Opts
---@return obsidian.Client
obsidian.setup = function(opts)
  local self = obsidian.new(opts.dir)
  -- Ensure directory exists.
  self.dir:mkdir { parents = true, exits_ok = true }

  local completion = opts.completion and opts.completion or {}

  -- Complete the lazy setup only when entering a buffer in the vault.
  local lazy_setup = function()
    -- Configure nvim-cmp completion?
    if completion.nvim_cmp then
      -- Check for ripgrep.
      if os.execute "rg --help" > 0 then
        error "[Obsidian] Can't find 'rg' command! Did you forget to install ripgrep?"
      end

      -- Add source.
      local cmp = require "cmp"
      local sources = {
        { name = "obsidian", option = { dir = tostring(self.dir) } },
        { name = "obsidian_new", option = { dir = tostring(self.dir) } },
      }
      for _, source in pairs(cmp.get_config().sources) do
        if source.name ~= "obsidian" and source.name ~= "obsidian_new" then
          table.insert(sources, source)
        end
      end
      cmp.setup.buffer { sources = sources }
    end
  end

  local group = vim.api.nvim_create_augroup("obsidian_setup", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    pattern = tostring(self.dir) .. "/**.md",
    callback = lazy_setup,
  })

  return self
end

---Search for notes. Returns an iterator over matching notes.
---
---@param search string
client.search = function(self, search)
  local search_results = obsidian.util.search(self.dir, search)
  return function()
    local path = search_results()
    if path == nil then
      return nil
    else
      return obsidian.note.from_file(path, self.dir)
    end
  end
end

return obsidian
