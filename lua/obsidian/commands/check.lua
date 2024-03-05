local Note = require "obsidian.note"
local log = require "obsidian.log"
local iter = require("obsidian.itertools").iter

---@param client obsidian.Client
return function(client, _)
  local start_time = vim.loop.hrtime()
  local count = 0
  local errors = {}
  local warnings = {}
  local opts = {
    timeout = 5000,
    on_done = function()
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
    end,
  }

  client:apply_async_raw(function(path)
    local relative_path = client:vault_relative_path(path, { strict = true })
    local ok, res = pcall(Note.from_file_async, path)

    if not ok then
      errors[#errors + 1] = string.format("Failed to parse note '%s': ", relative_path, res)
    elseif res.has_frontmatter == false then
      warnings[#warnings + 1] = string.format("'%s' missing frontmatter", relative_path)
    end

    count = count + 1
  end, opts)
end
