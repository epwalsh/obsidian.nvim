local Path = require "plenary.path"

local obsidian = {}

obsidian.note = require "obsidian.note"
obsidian.cache = require "obsidian.cache"
obsidian.util = require "obsidian.util"

---@class obsidian.Client
---@field dir Path
---@field cache obsidian.Cache
local client = {}

--[[
-- Options classes:
--]]

---@class obsidian.Opts
---@field dir string
---@field completion obsidian.CompletionOpts

---@class obsidian.CompletionOpts
---@field nvim_cmp boolean

---Create a new Obsidian client without additional setup.
---
---@param dir string
---@return obsidian.Client
obsidian.new = function(dir)
  local self = setmetatable({}, { __index = client })
  self.dir = Path:new(vim.fs.normalize(dir and dir or "./"))
  self.cache = obsidian.cache.new(self.dir)
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
    -- Load cache if needed.
    if self.cache:size() == 0 then
      self:load_cache()
    end

    -- Configure nvim-cmp completion?
    if completion.nvim_cmp then
      local cmp = require "cmp"
      local sources = {
        { name = "obsidian", option = { dir = tostring(self.dir) } },
      }
      for _, source in pairs(cmp.get_config().sources) do
        if source.name ~= "obsidian" then
          table.insert(sources, source)
        end
      end
      cmp.setup.buffer { sources = sources }
    end

    -- All good!
    print "[Obsidian] loaded!"
  end

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = tostring(self.dir) .. "/**.md",
    callback = lazy_setup,
  })

  return self
end

---Load cache.
---
---@param refresh boolean|?
client.load_cache = function(self, refresh)
  if refresh then
    self.cache:clear()
  end
  for _, fname in pairs(obsidian.util.find_markdown_files(self.dir)) do
    local path = Path:new(fname)
    if path:is_file() then
      local note = obsidian.note.from_file(path, self.dir)
      self.cache:set(note)
    end
  end
end

return obsidian
