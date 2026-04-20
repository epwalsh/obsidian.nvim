local abc = require "obsidian.abc"
local completion = require "obsidian.completion.tags"
local iter = require("obsidian.itertools").iter
local obsidian = require "obsidian"
local util = require "obsidian.util"

---Used to track variables that are used between reusable method calls. This is required, because each
---call to the sources's completion hook won't create a new source object, but will reuse the same one.
---@class obsidian.completion.sources.base.TagsSourceCompletionContext : obsidian.ABC
---@field client obsidian.Client
---@field completion_resolve_callback (fun(self: any)) blink or nvim_cmp completion resolve callback
---@field request obsidian.completion.sources.base.Request
---@field search string|?
---@field in_frontmatter boolean|?
local TagsSourceCompletionContext = abc.new_class()

TagsSourceCompletionContext.new = function()
  return TagsSourceCompletionContext.init()
end

---@class obsidian.completion.sources.base.TagsSourceBase : obsidian.ABC
---@field incomplete_response table
---@field complete_response table
local TagsSourceBase = abc.new_class()

---@return obsidian.completion.sources.base.TagsSourceBase
TagsSourceBase.new = function()
  return TagsSourceBase.init()
end

TagsSourceBase.get_trigger_characters = completion.get_trigger_characters

---Sets up a new completion context that is used to pass around variables between completion source methods
---@param completion_resolve_callback (fun(self: any)) blink or nvim_cmp completion resolve callback
---@param request obsidian.completion.sources.base.Request
---@return obsidian.completion.sources.base.TagsSourceCompletionContext
function TagsSourceBase:new_completion_context(completion_resolve_callback, request)
  local completion_context = TagsSourceCompletionContext.new()

  -- Sets up the completion callback, which will be called when the (possibly incomplete) completion items are ready
  completion_context.completion_resolve_callback = completion_resolve_callback

  -- This request object will be used to determine the current cursor location and the text around it
  completion_context.request = request

  completion_context.client = assert(obsidian.get_client())

  return completion_context
end

--- Runs a generalized version of the complete (nvim_cmp) or get_completions (blink) methods
---@param cc obsidian.completion.sources.base.TagsSourceCompletionContext
function TagsSourceBase:process_completion(cc)
  if not self:can_complete_request(cc) then
    return
  end

  local search_opts = cc.client.search_defaults()
  search_opts.sort = false

  cc.client:find_tags_async(cc.search, function(tag_locs)
    local tags = {}
    for tag_loc in iter(tag_locs) do
      tags[tag_loc.tag] = true
    end

    local items = {}
    for tag, _ in pairs(tags) do
      items[#items + 1] = {
        sortText = "#" .. tag,
        label = "Tag: #" .. tag,
        kind = vim.lsp.protocol.CompletionItemKind.Text,
        insertText = "#" .. tag,
        data = {
          bufnr = cc.request.context.bufnr,
          in_frontmatter = cc.in_frontmatter,
          line = cc.request.context.cursor.line,
          tag = tag,
        },
      }
    end

    cc.completion_resolve_callback(vim.tbl_deep_extend("force", self.complete_response, { items = items }))
  end, { search = search_opts })
end

--- Returns whatever it's possible to complete the search and sets up the search related variables in cc
---@param cc obsidian.completion.sources.base.TagsSourceCompletionContext
---@return boolean success provides a chance to return early if the request didn't meet the requirements
function TagsSourceBase:can_complete_request(cc)
  local can_complete
  can_complete, cc.search, cc.in_frontmatter = completion.can_complete(cc.request)

  if not (can_complete and cc.search ~= nil and #cc.search >= cc.client.opts.completion.min_chars) then
    cc.completion_resolve_callback(self.incomplete_response)
    return false
  end

  return true
end

--- Runs a generalized version of the execute method
---@param item any
function TagsSourceBase:process_execute(item)
  if item.data.in_frontmatter then
    -- Remove the '#' at the start of the tag.
    -- TODO: ideally we should be able to do this by specifying the completion item in the right way,
    -- but I haven't figured out how to do that.
    local line = vim.api.nvim_buf_get_lines(item.data.bufnr, item.data.line, item.data.line + 1, true)[1]
    line = util.string_replace(line, "#" .. item.data.tag, item.data.tag, 1)
    vim.api.nvim_buf_set_lines(item.data.bufnr, item.data.line, item.data.line + 1, true, { line })
  end
end

return TagsSourceBase
