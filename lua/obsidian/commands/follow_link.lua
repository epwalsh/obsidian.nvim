local RefTypes = require("obsidian.search").RefTypes
local util = require "obsidian.util"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  client:resolve_link_async(nil, function(res)
    if res == nil then
      return
    end

    if res.url ~= nil then
      if client.opts.follow_url_func ~= nil then
        client.opts.follow_url_func(res.url)
      else
        log.warn "This looks like a URL. You can customize the behavior of URLs with the 'follow_url_func' option."
      end
      return
    end

    local open_cmd = "e "
    if string.len(data.args) > 0 then
      open_cmd = util.get_open_strategy(data.args)
    end

    if res.note ~= nil then
      -- Go to resolved note.
      local path = assert(res.path)
      return vim.schedule(function()
        vim.api.nvim_command(open_cmd .. tostring(path))
      end)
    end

    if res.link_type == RefTypes.Wiki or res.link_type == RefTypes.WikiWithAlias then
      -- Prompt to create a new note.
      return vim.schedule(function()
        local confirmation = string.lower(vim.fn.input {
          prompt = "Create new note '" .. res.location .. "'? [Y/n] ",
        })
        if confirmation == "" or confirmation == "y" or confirmation == "yes" then
          -- Create a new note.
          ---@type string|?, string[]
          local id, aliases
          if res.name == res.location then
            aliases = {}
          else
            aliases = { res.name }
            id = res.location
          end

          local note = client:new_note(res.name, id, nil, aliases)
          vim.api.nvim_command(open_cmd .. tostring(note.path))
        else
          log.warn "Aborting"
        end
      end)
    end

    return log.err("Failed to resolve file '" .. res.location .. "'")
  end)
end
