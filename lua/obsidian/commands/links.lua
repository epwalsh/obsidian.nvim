local log = require "obsidian.log"
local search = require "obsidian.search"
local iter = require("obsidian.itertools").iter

---@param client obsidian.Client
return function(client)
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  ---@type string[]
  local links = {}
  for line in iter(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
    for match in iter(search.find_refs(line, { include_naked_urls = true })) do
      local m_start, m_end = unpack(match)
      local link = string.sub(line, m_start, m_end)
      links[#links + 1] = link
    end
  end

  picker:pick(links, {
    prompt_title = "Links",
    callback = function(link)
      client:follow_link_async(link)
    end,
  })
end
