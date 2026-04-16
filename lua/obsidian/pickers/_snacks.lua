local snacks_picker = require "snacks.picker"

local Path = require "obsidian.path"
local abc = require "obsidian.abc"
local Picker = require "obsidian.pickers.picker"

local function debug_once(msg, ...)
--    vim.notify(msg .. vim.inspect(...))
end

---@param mapping table
---@return table
local function notes_mappings(mapping)
    if type(mapping) == "table" then
        opts = { win = { input = { keys = {} } }, actions = {} };
        for k, v in pairs(mapping) do
            local name = string.gsub(v.desc, " ", "_")
            opts.win.input.keys = {
                [k] = { name, mode = { "n", "i" }, desc = v.desc }
            }
            opts.actions[name] = function(picker, item)
                debug_once("mappings :", item)
                picker:close()
                vim.schedule(function()
                    v.callback(item.value or item._path)
                end)
            end
        end
        return opts
    end
    return {}
end

---@class obsidian.pickers.SnacksPicker : obsidian.Picker
local SnacksPicker = abc.new_class({
    ---@diagnostic disable-next-line: unused-local
    __tostring = function(self)
        return "SnacksPicker()"
    end,
}, Picker)

---@param opts obsidian.PickerFindOpts|? Options.
SnacksPicker.find_files = function(self, opts)
    opts = opts or {}

    ---@type obsidian.Path
    local dir = opts.dir.filename and Path:new(opts.dir.filename) or self.client.dir

    local map = vim.tbl_deep_extend("force", {},
        notes_mappings(opts.selection_mappings))

    local pick_opts = vim.tbl_extend("force", map or {}, {
        source = "files",
        title = opts.prompt_title,
        cwd = tostring(dir),
        confirm = function(picker, item, action)
            picker:close()
            if item then
                if opts.callback then
                    debug_once("find files callback: ", item)
                    opts.callback(item._path)
                else
                    debug_once("find files jump: ", item)
                    snacks_picker.actions.jump(picker, item, action)
                end
            end
        end,
    })
    local t = snacks_picker.pick(pick_opts)
end

---@param opts obsidian.PickerGrepOpts|? Options.
SnacksPicker.grep = function(self, opts)
    opts = opts or {}

    debug_once("grep opts : ", opts)

    ---@type obsidian.Path
    local dir = opts.dir.filename and Path:new(opts.dir.filename) or self.client.dir

    local map = vim.tbl_deep_extend("force", {},
        notes_mappings(opts.selection_mappings))

    local pick_opts = vim.tbl_extend("force", map or {}, {
        source = "grep",
        title = opts.prompt_title,
        cwd = tostring(dir),
        confirm = function(picker, item, action)
            picker:close()
            if item then
                if opts.callback then
                    debug_once("grep callback: ", item)
                    opts.callback(item._path or item.filename)
                else
                    debug_once("grep jump: ", item)
                    snacks_picker.actions.jump(picker, item, action)
                end
            end
        end,
    })
    snacks_picker.pick(pick_opts)
end

---@param values string[]|obsidian.PickerEntry[]
---@param opts obsidian.PickerPickOpts|? Options.
---@diagnostic disable-next-line: unused-local
SnacksPicker.pick = function(self, values, opts)
    self.calling_bufnr = vim.api.nvim_get_current_buf()

    opts = opts or {}

    debug_once("pick opts: ", opts)

    local buf = opts.buf or vim.api.nvim_get_current_buf()

    local entries = {}
    for _, value in ipairs(values) do
        if type(value) == "string" then
            table.insert(entries, {
                text = value,
                value = value,
            })
        elseif value.valid ~= false then
            local name = self:_make_display(value)
            table.insert(entries, {
                text = name,
                buf = buf,
                filename = value.filename,
                value = value.value,
                pos = { value.lnum, value.col or 0 },
            })
        end
    end

    local map = vim.tbl_deep_extend("force", {},
        notes_mappings(opts.selection_mappings))

    local pick_opts = vim.tbl_extend("force", map or {}, {
        tilte = opts.prompt_title,
        items = entries,
        layout = {
            preview = false
        },
        format = "text",
        confirm = function(picker, item, action)
            picker:close()
            if item then
                if opts.callback then
                    debug_once("pick callback: ", item)
                    opts.callback(item.value)
                else
                    debug_once("pick jump: ", item)
                    snacks_picker.actions.jump(picker, item, action)
                end
            end
        end,
    })

    local entry = snacks_picker.pick(pick_opts)
end

return SnacksPicker
