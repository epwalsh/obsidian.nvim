local util = require "obsidian.util"
local log = require "obsidian.log"
local RefTypes = require("obsidian.search").RefTypes

---@param client obsidian.Client
return function(client, data)
  local vault_name = client:vault_name()
  local this_os = util.get_os()

  -- Resolve path of note to open.
  ---@type string|?
  local path
  if data.args:len() > 0 then
    local note = client:resolve_note(data.args)
    if note ~= nil then
      path = assert(client:vault_relative_path(note.path))
    else
      log.err "Could not resolve arguments to a note ID, path, or alias"
      return
    end
  else
    local cursor_link, _, ref_type = util.cursor_link()
    if cursor_link ~= nil and ref_type ~= RefTypes.NakedUrl then
      local note = client:resolve_note(cursor_link)
      if note ~= nil then
        path = assert(client:vault_relative_path(note.path))
      else
        log.err "Could not resolve link under cursor to a note ID, path, or alias"
        return
      end
    else
      -- bufname is an absolute path to the buffer.
      local bufname = vim.api.nvim_buf_get_name(0)
      path = client:vault_relative_path(bufname)
      if path == nil then
        log.err("Current buffer '" .. bufname .. "' does not appear to be inside the vault")
        return
      end
    end
  end

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

  ---@type string, string[]
  local cmd, args
  if this_os == util.OSType.Linux then
    cmd = "xdg-open"
    args = { uri }
  elseif this_os == util.OSType.Wsl then
    cmd = "wsl-open"
    args = { uri }
  elseif this_os == util.OSType.Windows then
    cmd = "powershell"
    args = { "Start-Process '" .. uri .. "'" }
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

  vim.uv.spawn(cmd, { args = args, detach = true }, function(code, signal)
    if code ~= 0 then
      log.err("open command failed with code " .. code)
    end
    if signal ~= 0 then
      log.err("open command failed with signal " .. signal)
    end
  end)
end
