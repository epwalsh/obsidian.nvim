local Path = require "plenary.path"
local Note = require "obsidian.note"
local log = require "obsidian.log"
local iter = require("obsidian.itertools").iter
local AsyncExecutor = require("obsidian.async").AsyncExecutor
local scan = require "plenary.scandir"

---@param client obsidian.Client
return function(client, _)
  local skip_dirs = {}
  if client.opts.templates ~= nil and client.opts.templates.subdir ~= nil then
    skip_dirs[#skip_dirs + 1] = Path:new(client.opts.templates.subdir)
  end

  local executor = AsyncExecutor.new()
  local count = 0
  local errors = {}
  local warnings = {}

  ---@param path Path
  local function check_note(path, relative_path)
    local ok, res = pcall(Note.from_file_async, path, client.dir)
    if not ok then
      errors[#errors + 1] = "Failed to parse note '" .. relative_path .. "': " .. tostring(res)
    elseif res.has_frontmatter == false then
      warnings[#warnings + 1] = "'" .. relative_path .. "' missing frontmatter"
    end
    count = count + 1
  end

  ---@diagnostic disable-next-line: undefined-field
  local start_time = vim.loop.hrtime()

  scan.scan_dir(vim.fs.normalize(tostring(client.dir)), {
    hidden = false,
    add_dirs = false,
    respect_gitignore = true,
    search_pattern = ".*%.md",
    on_insert = function(entry)
      local relative_path = assert(client:vault_relative_path(entry))
      for skip_dir in iter(skip_dirs) do
        if vim.startswith(relative_path, tostring(skip_dir) .. skip_dir._sep) then
          return
        end
      end
      executor:submit(check_note, nil, entry, relative_path)
    end,
  })

  executor:join_and_then(5000, function()
    ---@diagnostic disable-next-line: undefined-field
    local runtime = math.floor((vim.loop.hrtime() - start_time) / 1000000)
    local messages = { "Checked " .. tostring(count) .. " notes in " .. runtime .. "ms" }
    local log_level = vim.log.levels.INFO
    if #warnings > 0 then
      messages[#messages + 1] = "\nThere were " .. tostring(#warnings) .. " warning(s):"
      log_level = vim.log.levels.WARN
      for warning in iter(warnings) do
        messages[#messages + 1] = "  " .. warning
      end
    end
    if #errors > 0 then
      messages[#messages + 1] = "\nThere were " .. tostring(#errors) .. " error(s):"
      for err in iter(errors) do
        messages[#messages + 1] = "  " .. err
      end
      log_level = vim.log.levels.ERROR
    end
    log.log(table.concat(messages, "\n"), log_level)
  end)
end
