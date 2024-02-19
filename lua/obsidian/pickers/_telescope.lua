local telescope = require "telescope.builtin"
local Path = require "plenary.path"
local abc = require "obsidian.abc"
local Picker = require "obsidian.pickers.picker"

---@class obsidian.pickers.TelescopePicker : obsidian.Picker
local TelescopePicker = abc.new_class({}, Picker)

---@param opts { prompt_title: string|?, no_default_mappings: boolean|?, dir: string|Path|? }
---
---@return string
TelescopePicker.prompt_title = function(self, opts)
  local name = opts.prompt_title and opts.prompt_title or "Find"
  local prompt_title = name .. " | <CR> select"
  if opts.no_default_mappings then
    return prompt_title
  end
  local keys = self.client.opts.picker.mappings.new
  if keys ~= nil then
    prompt_title = prompt_title .. " | " .. keys .. " new"
  end
  keys = self.client.opts.picker.mappings.insert_link
  if keys ~= nil then
    prompt_title = prompt_title .. " | " .. keys .. " insert link"
  end
  return prompt_title
end

---@param initial_query string|?
TelescopePicker.default_mappings = function(self, map, initial_query)
  -- Docs for telescope actions:
  -- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/actions/init.lua
  local telescope_actions = require("telescope.actions.mt").transform_mod {
    obsidian_new = function(prompt_bufnr)
      local query = require("telescope.actions.state").get_current_line()
      if not query or string.len(query) == 0 then
        query = initial_query
      end
      require("telescope.actions").close(prompt_bufnr)
      self.client:command("ObsidianNew", { args = query })
    end,

    obsidian_insert_link = function(prompt_bufnr)
      require("telescope.actions").close(prompt_bufnr)
      local path = require("telescope.actions.state").get_selected_entry().path
      local note = require("obsidian").Note.from_file(path, self.client.dir)
      local link = self.client:format_link(note, {})
      vim.api.nvim_put({ link }, "", false, true)
    end,
  }

  local new_mapping = self.client.opts.picker.mappings.new
  if new_mapping ~= nil then
    map({ "i", "n" }, new_mapping, telescope_actions.obsidian_new)
  end

  local insert_link_mapping = self.client.opts.picker.mappings.insert_link
  if insert_link_mapping ~= nil then
    map({ "i", "n" }, insert_link_mapping, telescope_actions.obsidian_insert_link)
  end

  return true
end

---@param opts { prompt_title: string|?, callback: fun(path: string)|?, no_default_mappings: boolean|?, dir: string|Path|? }|?
TelescopePicker.find_files = function(self, opts)
  opts = opts and opts or {}
  telescope.find_files {
    prompt_title = self:prompt_title(opts),
    cwd = opts.dir and tostring(opts.dir) or tostring(self.client.dir),
    find_command = self:_build_find_cmd(),
    attach_mappings = function(_, map)
      if not opts.no_default_mappings then
        self:default_mappings(map)
      end

      if opts.callback then
        map({ "i", "n" }, "<CR>", function(prompt_bufnr)
          local entry = require("telescope.actions.state").get_selected_entry()
          require("telescope.actions").close(prompt_bufnr)
          opts.callback(entry[1])
        end)
      end

      return true
    end,
  }
end

---@param opts { prompt_title: string|?, dir: string|Path|?, query: string|?, callback: fun(path: string)|?, no_default_mappings: boolean|? }|?
TelescopePicker.grep = function(self, opts)
  opts = opts and opts or {}

  local cwd = opts.dir and Path:new(opts.dir) or self.client.dir

  local attach_mappings = function(_, map)
    if not opts.no_default_mappings then
      self:default_mappings(map, opts.query)
    end

    if opts.callback then
      map({ "i", "n" }, "<CR>", function(prompt_bufnr)
        local filename = require("telescope.actions.state").get_selected_entry().filename
        require("telescope.actions").close(prompt_bufnr)
        opts.callback(tostring(cwd / filename))
      end)
    end

    return true
  end

  if opts.query and string.len(opts.query) > 0 then
    telescope.grep_string {
      prompt_title = self:prompt_title(opts),
      cwd = tostring(cwd),
      vimgrep_arguments = self:_build_grep_cmd(),
      search = opts.query,
      attach_mappings = attach_mappings,
    }
  else
    telescope.live_grep {
      prompt_title = self:prompt_title(opts),
      cwd = tostring(cwd),
      vimgrep_arguments = self:_build_grep_cmd(),
      attach_mappings = attach_mappings,
    }
  end
end

---@param values string[]|obsidian.PickerEntry[]
---@param opts { prompt_title: string|?, callback: fun(value: any)|? }|?
TelescopePicker.pick = function(self, values, opts)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local make_entry = require "telescope.make_entry"

  opts = opts and opts or {}

  local picker_opts = {
    attach_mappings = function(_, map)
      if opts.callback then
        map({ "i", "n" }, "<CR>", function(prompt_bufnr)
          local entry = require("telescope.actions.state").get_selected_entry()
          require("telescope.actions").close(prompt_bufnr)
          opts.callback(entry.value)
        end)
      end

      return true
    end,
  }

  local make_entry_from_string = make_entry.gen_from_string(picker_opts)

  pickers
    .new(picker_opts, {
      prompt_title = self:prompt_title { prompt_title = opts.prompt_title, no_default_mappings = true },
      finder = finders.new_table {
        results = values,
        entry_maker = function(v)
          if type(v) == "string" then
            return make_entry_from_string(v)
          else
            return v
          end
        end,
      },
      sorter = conf.generic_sorter(picker_opts),
      previewer = conf.grep_previewer(picker_opts),
    })
    :find()
end

return TelescopePicker
