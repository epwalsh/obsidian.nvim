local AsyncExecutor = require("obsidian.async").AsyncExecutor
local log = require "obsidian.log"
local search = require "obsidian.search"
local iter = require("obsidian.itertools").iter
local util = require "obsidian.util"
local channel = require("plenary.async.control").channel

---@param client obsidian.Client
return function(client)
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  -- Gather all unique raw links (strings) from the buffer.
  ---@type table<string, boolean>
  local links = {}
  for line in iter(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
    for match in iter(search.find_refs(line, { include_naked_urls = true, include_file_urls = true })) do
      local m_start, m_end = unpack(match)
      local link = string.sub(line, m_start, m_end)
      links[link] = true
    end
  end

  local executor = AsyncExecutor.new()

  executor:map(
    function(link)
      local tx, rx = channel.oneshot()
      local entry

      client:resolve_link_async(link, function(res)
        local icon, icon_hl
        if res.url ~= nil then
          icon, icon_hl = util.get_icon(res.url)
        end

        if res ~= nil then
          entry = {
            value = link,
            display = res.name,
            filename = res.path and tostring(res.path) or nil,
            icon = icon,
            icon_hl = icon_hl,
          }
        else
          entry = {
            value = link,
            valid = false,
          }
        end

        tx()
      end)

      rx()
      return entry
    end,
    vim.tbl_keys(links),
    function(results)
      vim.schedule(function()
        -- Flatten entries.
        local entries = {}
        for res in iter(results) do
          entries[#entries + 1] = res[1]
        end

        -- Launch picker.
        picker:pick(entries, {
          prompt_title = "Links",
          callback = function(link)
            client:follow_link_async(link)
          end,
        })
      end)
    end
  )
end
