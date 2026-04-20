local NewNoteSourceBase = require "obsidian.completion.sources.base.new"
local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local nvim_cmp_util = require "obsidian.completion.sources.nvim_cmp.util"

---@class obsidian.completion.sources.nvim_cmp.NewNoteSource : obsidian.completion.sources.base.NewNoteSourceBase
local NewNoteSource = abc.new_class()

NewNoteSource.new = function()
  return NewNoteSource.init(NewNoteSourceBase)
end

NewNoteSource.get_keyword_pattern = completion.get_keyword_pattern

NewNoteSource.incomplete_response = nvim_cmp_util.incomplete_response
NewNoteSource.complete_response = nvim_cmp_util.complete_response

---Invoke completion (required).
---@param request cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function NewNoteSource:complete(request, callback)
  local cc = self:new_completion_context(callback, request)
  self:process_completion(cc)
end

---Creates a new note using the default template for the completion item.
---Executed after the item was selected.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function NewNoteSource:execute(completion_item, callback)
  return callback(self:process_execute(completion_item))
end

return NewNoteSource
