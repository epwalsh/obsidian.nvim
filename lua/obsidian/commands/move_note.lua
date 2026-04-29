local Path = require "obsidian.path"
local log = require "obsidian.log"
local util = require "obsidian.util"

---@param root obsidian.Path
---@return obsidian.Path[]
local function collect_dirs(root)
  ---@type obsidian.Path[]
  local dirs = { root }

  ---@param dir obsidian.Path
  local function walk(dir)
    for name, kind in vim.fs.dir(tostring(dir)) do
      if kind == "directory" then
        local child = dir / name
        dirs[#dirs + 1] = child
        walk(child)
      end
    end
  end

  walk(root)
  table.sort(dirs, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return dirs
end

---@param client obsidian.Client
return function(client, _)
  local note = client:current_note(0)
  if not note then
    log.err "Current buffer is not a markdown note"
    return
  end

  local source_path = Path.buffer(0)
  local source_parent = assert(source_path:parent())
  local source_filename = assert(source_path.name)

  local ok = pcall(function()
    client:vault_relative_path(source_path, { strict = true })
  end)
  if not ok then
    log.err("Current note '%s' is outside of the current vault '%s'", source_path, client.dir)
    return
  end

  local all_dirs = collect_dirs(client.dir)
  ---@type string[]
  local options = {}
  ---@type table<string, obsidian.Path>
  local option_to_dir = {}

  for _, dir in ipairs(all_dirs) do
    local label
    if dir == client.dir then
      label = "/"
    else
      local rel = client:vault_relative_path(dir, { strict = true })
      label = tostring(rel)
    end
    options[#options + 1] = label
    option_to_dir[label] = dir
  end

  local function move_to_dir(target_dir_label)
    if not target_dir_label then
      log.warn "Move aborted"
      return
    end

    local target_dir = option_to_dir[target_dir_label]
    if not target_dir then
      log.err("Invalid target directory '%s'", tostring(target_dir_label))
      return
    end

    if target_dir == source_parent then
      log.info "Note is already in that directory"
      return
    end

    local target_path = target_dir / source_filename
    if target_path:exists() then
      log.err("A note already exists at '%s'", target_path)
      return
    end

    target_dir:mkdir { parents = true, exist_ok = true }

    client._quiet = true
    local save_ok, save_err = pcall(vim.cmd.write)
    if not save_ok then
      client._quiet = false
      error(save_err)
    end

    local saveas_ok, saveas_err = pcall(vim.cmd.saveas, vim.fn.fnameescape(tostring(target_path)))
    client._quiet = false
    if not saveas_ok then
      error(saveas_err)
    end

    for bufnr, bufname in util.get_named_buffers() do
      if bufname == tostring(source_path) then
        vim.cmd.bdelete(bufnr)
      end
    end

    source_path:unlink()

    log.info("Moved note to '%s'", target_path)
  end

  local picker = client:picker()
  if picker then
    picker:pick(options, {
      prompt_title = "Move note to folder",
      callback = move_to_dir,
    })
  else
    vim.ui.select(options, { prompt = "Move note to folder" }, move_to_dir)
  end
end
