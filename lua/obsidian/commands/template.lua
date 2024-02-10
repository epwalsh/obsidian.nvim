local templates = require "obsidian.templates"
local log = require "obsidian.log"
local util = require "obsidian.util"

---@param client obsidian.Client
return function(client, data)
  if not client:templates_dir() then
    log.err "Templates folder is not defined or does not exist"
    return
  end

  -- We need to get this upfront before the picker hijacks the current window.
  local insert_location = util.get_active_window_cursor_location()

  local function insert_template(name)
    templates.insert_template(name, client, insert_location)
  end

  if string.len(data.args) > 0 then
    local template_name = data.args
    local path = client:templates_dir() / template_name
    if path:is_file() then
      insert_template(data.args)
    else
      log.err "Not a valid template file"
    end
    return
  end

  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  picker:find_templates {
    callback = function(path)
      insert_template(vim.fs.basename(path))
    end,
  }
end
