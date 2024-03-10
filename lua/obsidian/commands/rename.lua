local Path = require "obsidian.path"
local Note = require "obsidian.note"
local AsyncExecutor = require("obsidian.async").AsyncExecutor
local File = require("obsidian.async").File
local log = require "obsidian.log"
local search = require "obsidian.search"
local util = require "obsidian.util"
local enumerate = require("obsidian.itertools").enumerate
local zip = require("obsidian.itertools").zip

---@param client obsidian.Client
return function(client, data)
  -- Validate args.
  local dry_run = false
  ---@type string
  local arg

  if data.args == "--dry-run" then
    dry_run = true
    data.args = nil
  end

  if data.args ~= nil and string.len(data.args) > 0 then
    arg = util.strip_whitespace(data.args)
  else
    arg = vim.fn.input {
      prompt = "Enter new note ID/name/path: ",
    }
    if not arg or string.len(arg) == 0 then
      log.warn "Rename aborted"
      return
    end
  end

  if vim.endswith(arg, " --dry-run") then
    dry_run = true
    arg = util.strip_whitespace(string.sub(arg, 1, -string.len " --dry-run" - 1))
  end

  -- Resolve the note to rename.
  ---@type boolean
  local is_current_buf
  ---@type integer|?
  local cur_note_bufnr
  ---@type obsidian.Path
  local cur_note_path
  ---@type obsidian.Note
  local cur_note
  local cur_note_id = util.parse_cursor_link()
  if cur_note_id == nil then
    is_current_buf = true
    cur_note_bufnr = assert(vim.fn.bufnr())
    cur_note_path = Path.buffer(cur_note_bufnr)
    cur_note = Note.from_file(cur_note_path)
    cur_note_id = tostring(cur_note.id)
  else
    local notes = { client:resolve_note(cur_note_id) }
    if #notes == 0 then
      log.err("Failed to resolve '%s' to a note", cur_note_id)
      return
    elseif #notes > 1 then
      log.err("Failed to resolve '%s' to a single note, found %d matches", cur_note_id, #notes)
      return
    else
      cur_note = notes[1]
    end

    is_current_buf = false
    cur_note_id = tostring(cur_note.id)
    cur_note_path = cur_note.path
    for bufnr, bufpath in util.get_named_buffers() do
      if bufpath == cur_note_path then
        cur_note_bufnr = bufnr
        break
      end
    end
  end

  assert(cur_note_path)
  local dirname = assert(cur_note_path:parent(), string.format("failed to resolve parent of '%s'", cur_note_path))

  -- Parse new note ID / path from args.
  local parts = vim.split(arg, "/", { plain = true })
  local new_note_id = parts[#parts]
  if new_note_id == "" then
    log.err "Invalid new note ID"
    return
  elseif vim.endswith(new_note_id, ".md") then
    new_note_id = string.sub(new_note_id, 1, -4)
  end

  ---@type obsidian.Path
  local new_note_path
  if #parts > 1 then
    parts[#parts] = nil
    new_note_path = client.dir:joinpath(unpack(vim.tbl_flatten { parts, new_note_id })):with_suffix ".md"
  else
    new_note_path = (dirname / new_note_id):with_suffix ".md"
  end

  if new_note_id == cur_note_id then
    log.warn "New note ID is the same, doing nothing"
    return
  end

  -- Get confirmation before continuing.
  local confirmation
  if not dry_run then
    confirmation = util.confirm(
      "Renaming '"
        .. cur_note_id
        .. "' to '"
        .. new_note_id
        .. "'...\n"
        .. "This will write all buffers and potentially modify a lot of files. If you're using version control "
        .. "with your vault it would be a good idea to commit the current state of your vault before running this.\n"
        .. "You can also do a dry run of this by running ':ObsidianRename "
        .. arg
        .. " --dry-run'.\n"
        .. "Do you want to continue?"
    )
  else
    confirmation = util.confirm(
      "Dry run: renaming '" .. cur_note_id .. "' to '" .. new_note_id .. "'...\n" .. "Do you want to continue?"
    )
  end

  if not confirmation then
    log.warn "Rename aborted"
    return
  end

  ---@param fn function
  local function quietly(fn, ...)
    client._quiet = true
    local ok, res = pcall(fn, ...)
    client._quiet = false
    if not ok then
      error(res)
    end
  end

  -- Write all buffers.
  quietly(vim.cmd.wall)

  -- Rename the note file and remove or rename the corresponding buffer, if there is one.
  if cur_note_bufnr ~= nil then
    if is_current_buf then
      -- If we're renaming the note of a current buffer, save as the new path.
      if not dry_run then
        quietly(vim.cmd.saveas, tostring(new_note_path))
        for bufnr, bufname in util.get_named_buffers() do
          if bufname == cur_note_path then
            quietly(vim.cmd.bdelete, bufnr)
          end
        end
        vim.fn.delete(tostring(cur_note_path))
      else
        log.info("Dry run: saving current buffer as '" .. new_note_path .. "' and removing old file")
      end
    else
      -- For the non-current buffer the best we can do is delete the buffer (we've already saved it above)
      -- and then make a file-system call to rename the file.
      if not dry_run then
        quietly(vim.cmd.bdelete, cur_note_bufnr)
        cur_note_path:rename(new_note_path)
      else
        log.info("Dry run: removing buffer '" .. cur_note_path .. "' and renaming file to '" .. new_note_path .. "'")
      end
    end
  else
    -- When the note is not loaded into a buffer we just need to rename the file.
    if not dry_run then
      cur_note_path:rename(new_note_path)
    else
      log.info("Dry run: renaming file '" .. cur_note_path .. "' to '" .. new_note_path .. "'")
    end
  end

  if not is_current_buf then
    -- When the note to rename is not the current buffer we need to update its frontmatter
    -- to account for the rename.
    cur_note.id = new_note_id
    cur_note.path = Path.new(new_note_path)
    if not dry_run then
      cur_note:save()
    else
      log.info("Dry run: updating frontmatter of '" .. new_note_path .. "'")
    end
  end

  local cur_note_rel_path = tostring(client:vault_relative_path(cur_note_path, { strict = true }))
  local new_note_rel_path = tostring(client:vault_relative_path(new_note_path, { strict = true }))

  -- Search notes on disk for any references to `cur_note_id`.
  -- We look for the following forms of references:
  -- * '[[cur_note_id]]'
  -- * '[[cur_note_id|ALIAS]]'
  -- * '[[cur_note_id\|ALIAS]]' (a wiki link within a table)
  -- * '[ALIAS](cur_note_id)'
  -- And all of the above with relative paths (from the vault root) to the note instead of just the note ID,
  -- with and without the ".md" suffix.
  -- Another possible form is [[ALIAS]], but we don't change the note's aliases when renaming
  -- so those links will still be valid.
  ---@param ref_link string
  ---@return string[]
  local function get_ref_forms(ref_link)
    return {
      "[[" .. ref_link .. "]]",
      "[[" .. ref_link .. "|",
      "[[" .. ref_link .. "\\|",
      "[[" .. ref_link .. "#",
      "](" .. ref_link .. ")",
      "](" .. ref_link .. "#",
    }
  end

  local reference_forms = vim.tbl_flatten {
    get_ref_forms(cur_note_id),
    get_ref_forms(cur_note_rel_path),
    get_ref_forms(string.sub(cur_note_rel_path, 1, -4)),
  }
  local replace_with = vim.tbl_flatten {
    get_ref_forms(new_note_id),
    get_ref_forms(new_note_rel_path),
    get_ref_forms(string.sub(new_note_rel_path, 1, -4)),
  }

  local executor = AsyncExecutor.new()

  local file_count = 0
  local replacement_count = 0
  local all_tasks_submitted = false

  ---@param path string|obsidian.Path
  ---@return integer
  local function replace_refs(path)
    --- Read lines, replacing refs as we go.
    local count = 0
    local lines = {}
    local f = File.open(tostring(path), "r")
    for line_num, line in enumerate(f:lines(true)) do
      for ref, replacement in zip(reference_forms, replace_with) do
        local n
        line, n = util.string_replace(line, ref, replacement)
        if dry_run and n > 0 then
          log.info(
            "Dry run: '"
              .. tostring(path)
              .. "':"
              .. line_num
              .. " Replacing "
              .. n
              .. " occurrence(s) of '"
              .. ref
              .. "' with '"
              .. replacement
              .. "'"
          )
        end
        count = count + n
      end
      lines[#lines + 1] = line
    end
    f:close()

    --- Write the new lines back.
    if not dry_run and count > 0 then
      f = File.open(tostring(path), "w")
      f:write_lines(lines)
      f:close()
    end

    return count
  end

  local function on_search_match(match)
    local path = Path.new(match.path.text):resolve { strict = true }
    file_count = file_count + 1
    executor:submit(replace_refs, function(count)
      replacement_count = replacement_count + count
    end, path)
  end

  search.search_async(
    client.dir,
    reference_forms,
    search.SearchOpts.from_tbl { fixed_strings = true, max_count_per_file = 1 },
    on_search_match,
    function(_)
      all_tasks_submitted = true
    end
  )

  -- Wait for all tasks to get submitted.
  vim.wait(2000, function()
    return all_tasks_submitted
  end, 50, false)

  -- Then block until all tasks are finished.
  executor:join(2000)

  local prefix = dry_run and "Dry run: replaced " or "Replaced "
  log.info(prefix .. replacement_count .. " reference(s) across " .. file_count .. " file(s)")

  -- In case the files of any current buffers were changed.
  vim.cmd.checktime()
end
