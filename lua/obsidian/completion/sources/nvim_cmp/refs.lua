local RefsSourceBase = require "obsidian.completion.sources.base.refs"
local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local nvim_cmp_util = require "obsidian.completion.sources.nvim_cmp.util"

---@class obsidian.completion.sources.nvim_cmp.CompletionItem
---@field label string
---@field new_text string
---@field sort_text string
---@field documentation table|?

---@class obsidian.completion.sources.nvim_cmp.RefsSource : obsidian.completion.sources.base.RefsSourceBase
local RefsSource = abc.new_class()

RefsSource.new = function()
  return RefsSource.init(RefsSourceBase)
end

RefsSource.get_keyword_pattern = completion.get_keyword_pattern

RefsSource.incomplete_response = nvim_cmp_util.incomplete_response
RefsSource.complete_response = nvim_cmp_util.complete_response

function RefsSource:complete(request, callback)
  local cc = self:new_completion_context(callback, request)
  self:process_completion(cc)
end

return RefsSource
