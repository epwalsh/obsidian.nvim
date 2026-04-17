local util = require "obsidian.util"
local log = require "obsidian.log"
local RefTypes = require("obsidian.search").RefTypes

---@param client obsidian.Client
---@param path string|obsidian.Path
local function open_in_app(client, path)
  path = tostring(client:vault_relative_path(path, { strict = true }))
  local vault_name = client:vault_name()
  local this_os = util.get_os()

  -- Normalize path for windows.
  if this_os == util.OSType.Windows then
    path = string.gsub(path, "/", "\\")
  end

  local encoded_vault = util.urlencode(vault_name)
  local encoded_path = util.urlencode(path)

  local uri
  if client.opts.use_advanced_uri then
    local line = vim.api.nvim_win_get_cursor(0)[1] or 1
    uri = ("obsidian://advanced-uri?vault=%s&filepath=%s&line=%i"):format(encoded_vault, encoded_path, line)
  else
    uri = ("obsidian://open?vault=%s&file=%s"):format(encoded_vault, encoded_path)
  end

  uri = vim.fn.shellescape(uri)
  ---@type string, string[]
  local cmd, args
  local run_in_shell = true
  if this_os == util.OSType.Linux or this_os == util.OSType.FreeBSD then
    cmd = "xdg-open"
    if client.opts.wayland == true then
      cmd = "obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland"
    end
    args = { uri }
  elseif this_os == util.OSType.Wsl then
    cmd = "wsl-open"
    args = { uri }
  elseif this_os == util.OSType.Windows then
    run_in_shell = false
    cmd = "powershell"
    args = { "Start-Process", uri }
  elseif this_os == util.OSType.Darwin then
    cmd = "open"
    if client.opts.open_app_foreground then
      args = { "-a", "/Applications/Obsidian.app", uri }
    else
      args = { "-a", "/Applications/Obsidian.app", "--background", uri }
    end
  else
    log.err("open command does not support OS type '" .. this_os .. "'")
    return
  end

  assert(cmd)
  assert(args)

  ---@type string|string[]
  local cmd_with_args
  if run_in_shell then
    cmd_with_args = cmd .. " " .. table.concat(args, " ")
  else
    cmd_with_args = { cmd, unpack(args) }
  end

  vim.fn.jobstart(cmd_with_args, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        log.err("open command failed with exit code '%s': %s", exit_code, cmd_with_args)
      end
    end,
  })
end

---@param client obsidian.Client
return function(client, data)
  ---@type string|?
  local search_term

  if data.args and data.args:len() > 0 then
    search_term = data.args
  else
    -- Check for a note reference under the cursor.
    local cursor_link, _, ref_type = util.parse_cursor_link()
    if cursor_link ~= nil and ref_type ~= RefTypes.NakedUrl and ref_type ~= RefTypes.FileUrl then
      search_term = cursor_link
    end
  end

  if search_term then
    -- Try to resolve search term to a single note.
    client:resolve_note_async_with_picker_fallback(search_term, function(note)
      vim.schedule(function()
        open_in_app(client, note.path)
      end)
    end, { prompt_title = "Select note to open" })
  else
    -- Otherwise use the path of the current buffer.
    local bufname = vim.api.nvim_buf_get_name(0)
    local path = client:vault_relative_path(bufname, { strict = true })
    if path == nil then
      log.err("Current buffer '%s' does not appear to be inside the vault", bufname)
      return
    else
      return open_in_app(client, path)
    end
  end
end
