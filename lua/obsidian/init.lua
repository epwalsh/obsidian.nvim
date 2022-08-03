local Pathlib = require "plenary.path"

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

---Setup a new Obsidian client.
---
---@param opts obsidian.Opts
---@return obsidian.Client
obsidian.setup = function(opts)
  local self = setmetatable({}, { __index = client })

  self.dir = Pathlib:new(vim.fs.normalize(opts.dir and opts.dir or "./"))
  -- Ensure directory exists.
  self.dir:mkdir { parents = true, exits_ok = true }
  self.cache = obsidian.cache.new(self.dir)

  local completion = opts.completion and opts.completion or {}

  -- Complete the lazy setup only when entering a buffer in the vault.
  local lazy_setup = function()
    -- Configure nvim-cmp completion?
    if completion.nvim_cmp then
      local cmp = require "cmp"
      local sources = {
        { name = "obsidian", option = { client = self } },
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
    pattern = tostring(self.dir) .. "/**/*.md",
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
    local path = Pathlib:new(fname)
    if path:is_file() then
      local note = obsidian.note.from_file(path)
      self.cache:set(note)
    end
  end
end

return obsidian
