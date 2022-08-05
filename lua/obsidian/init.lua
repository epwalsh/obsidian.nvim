local Path = require "plenary.path"

local obsidian = {}

obsidian.VERSION = "0.1.0"
obsidian.completion = require "obsidian.completion"
obsidian.config = require "obsidian.config"
obsidian.echo = require "obsidian.echo"
obsidian.note = require "obsidian.note"
obsidian.util = require "obsidian.util"

---@class obsidian.Client
---@field dir Path
local client = {}

---Create a new Obsidian client without additional setup.
---
---@param dir string|Path
---@return obsidian.Client
obsidian.new = function(dir)
  -- Setup highlight groups.
  obsidian.echo.setup()

  local self = setmetatable({}, { __index = client })
  self.dir = Path:new(vim.fs.normalize(tostring(dir and dir or "./")))

  return self
end

---Setup a new Obsidian client.
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Client
obsidian.setup = function(opts)
  opts = obsidian.config.ClientOpts.normalize(opts)
  local self = obsidian.new(opts.dir)

  -- Ensure directory exists.
  self.dir:mkdir { parents = true, exits_ok = true }

  -- Complete the lazy setup only when entering a buffer in the vault.
  local lazy_setup = function()
    -- Add commands...
    -- ':ObsidianCheck'
    vim.api.nvim_create_user_command(
      "ObsidianCheck",
      ---@diagnostic disable-next-line: unused-local
      function(data)
        self:validate()
      end,
      {}
    )

    -- ':ObsidianToday'
    vim.api.nvim_create_user_command(
      "ObsidianToday",
      ---@diagnostic disable-next-line: unused-local
      function(data)
        local note = obsidian.note.today(self.dir)
        if not note:exists() then
          note:save()
        end
        vim.api.nvim_command "w"
        vim.api.nvim_command("e " .. tostring(note.path))
      end,
      {}
    )

    -- ':ObsidianOpen'
    vim.api.nvim_create_user_command(
      "ObsidianOpen",
      ---@diagnostic disable-next-line: unused-local
      function(data)
        local vault = self:vault()
        if vault == nil then
          obsidian.echo.err "couldn't find an Obsidian vault"
          return
        end
        local vault_name = vim.fs.basename(vault)

        local path
        if data.args:len() > 0 then
          path = Path:new(data.args):make_relative(vault)
        else
          local bufname = vim.api.nvim_buf_get_name(0)
          path = Path:new(bufname):make_relative(vault)
        end

        local encoded_vault = obsidian.util.urlencode(vault_name)
        local encoded_path = obsidian.util.urlencode(tostring(path))

        -- TODO: make this work on Linux
        os.execute(
          "open -a /Applications/Obsidian.app --background 'obsidian://open?vault="
            .. encoded_vault
            .. "&file="
            .. encoded_path
            .. "'"
        )
      end,
      {}
    )

    -- Configure completion...
    if opts.completion.nvim_cmp then
      -- Check for ripgrep.
      if os.execute "rg --help" > 0 then
        obsidian.echo.err "Can't find 'rg' command! Did you forget to install ripgrep?"
      end

      -- Add source.
      local cmp = require "cmp"
      local sources = {
        { name = "obsidian", option = opts },
        { name = "obsidian_new", option = opts },
      }
      for _, source in pairs(cmp.get_config().sources) do
        if source.name ~= "obsidian" and source.name ~= "obsidian_new" then
          table.insert(sources, source)
        end
      end
      cmp.setup.buffer { sources = sources }
    end
  end

  -- Autocommands...
  local group = vim.api.nvim_create_augroup("obsidian_setup", { clear = true })

  -- Complete lazy setup on BufEnter
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    pattern = tostring(self.dir) .. "/**.md",
    callback = lazy_setup,
  })

  -- Add missing frontmatter on BufWritePre
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = group,
    pattern = tostring(self.dir) .. "/**.md",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local note = obsidian.note.from_buffer(bufnr, self.dir)
      if note:should_save_frontmatter() then
        local lines = note:frontmatter_lines()
        vim.api.nvim_buf_set_lines(bufnr, 0, 0, true, lines)
        obsidian.echo.info "Updated frontmatter"
      end
    end,
  })

  return self
end

---Find the path to the actual Obsidian vault (it may be in a parent of 'self.dir').
---
---@return string|?
client.vault = function(self)
  local vault_indicator_folder = ".obsidian"
  local dirs = self.dir:parents()
  table.insert(dirs, self.dir:absolute())
  for _, parent in pairs(self.dir:parents()) do
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local maybe_vault = Path:new(parent) / vault_indicator_folder
    if maybe_vault:is_dir() then
      return parent
    end
  end
  return nil
end

---Search for notes. Returns an iterator over matching notes.
---
---@param search string
---@return function
client.search = function(self, search)
  local search_results = obsidian.util.search(self.dir, search)

  ---@return obsidian.Note|?
  return function()
    local path = search_results()
    if path == nil then
      return nil
    else
      return obsidian.note.from_file(path, self.dir)
    end
  end
end

---Check directory for notes with missing/invalid frontmatter.
---
client.validate = function(self)
  local scan = require "plenary.scandir"

  local count = 0
  local err_count = 0
  local warn_count = 0

  scan.scan_dir(vim.fs.normalize(tostring(self.dir)), {
    hidden = false,
    add_dirs = false,
    respect_gitignore = true,
    search_pattern = ".*%.md",
    on_insert = function(entry)
      count = count + 1
      obsidian.note.from_file(entry, self.dir)
      local ok, note = pcall(obsidian.note.from_file, entry, self.dir)
      if not ok then
        err_count = err_count + 1
        obsidian.echo.err("Failed to parse note at " .. entry)
      elseif note.has_frontmatter == false then
        warn_count = warn_count + 1
        obsidian.echo.warn(tostring(entry) .. " is missing frontmatter")
      end
    end,
  })

  obsidian.echo.info("Found " .. tostring(count) .. " notes total")
  if warn_count > 0 then
    obsidian.echo.warn("There were " .. tostring(warn_count) .. " warnings")
  end
  if err_count > 0 then
    obsidian.echo.err("There were " .. tostring(err_count) .. " errors")
  end
end

return obsidian
