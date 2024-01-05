local Path = require "plenary.path"
local RefTypes = require("obsidian.search").RefTypes
local util = require "obsidian.util"
local log = require "obsidian.log"
local iter = require("obsidian.itertools").iter

---@param client obsidian.Client
return function(client, data)
  local location, name, link_type = util.cursor_link(nil, nil, true)
  if location == nil then
    return
  end

  -- Check if it's a URL.
  if util.is_url(location) then
    if client.opts.follow_url_func ~= nil then
      client.opts.follow_url_func(location)
    else
      log.warn "This looks like a URL. You can customize the behavior of URLs with the 'follow_url_func' option."
    end
    return
  end

  local open_cmd = "e "
  if string.len(data.args) > 0 then
    open_cmd = util.get_open_strategy(data.args)
  end

  -- Remove links from the end if there are any.
  local header_link = location:match "#[%a%d%s-_^]+$"
  if header_link ~= nil then
    location = location:sub(1, -header_link:len() - 1)
  end

  local buf_cwd = vim.fs.dirname(vim.api.nvim_buf_get_name(0))

  -- Search for matching notes.
  -- TODO: handle case where there are multiple matches by prompting user to choose.
  client:resolve_note_async(location, function(note)
    if note == nil and (link_type == RefTypes.Wiki or link_type == RefTypes.WikiWithAlias) then
      vim.schedule(function()
        local confirmation = string.lower(vim.fn.input {
          prompt = "Create new note '" .. location .. "'? [Y/n] ",
        })
        if confirmation == "y" or confirmation == "yes" then
          -- Create a new note.
          local aliases = name == location and {} or { name }
          note = client:new_note(location, nil, vim.fn.expand "%:p:h", aliases)
          vim.api.nvim_command(open_cmd .. tostring(note.path))
        else
          log.warn "Aborting"
        end
      end)
    elseif note ~= nil then
      -- Go to resolved note.
      local path = note.path
      assert(path)
      vim.schedule(function()
        vim.api.nvim_command(open_cmd .. tostring(path))
      end)
    else
      local paths_to_check = { client.dir / location, Path:new(location) }
      if buf_cwd ~= nil then
        paths_to_check[#paths_to_check + 1] = Path:new(buf_cwd) / location
      end

      for path in iter(paths_to_check) do
        if path:is_file() then
          return vim.schedule(function()
            vim.api.nvim_command(open_cmd .. tostring(path))
          end)
        end
      end
      return log.err("Failed to resolve file '" .. location .. "'")
    end
  end)
end
