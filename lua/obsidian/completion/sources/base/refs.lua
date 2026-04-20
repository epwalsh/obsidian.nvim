local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local LinkStyle = require("obsidian.config").LinkStyle
local obsidian = require "obsidian"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

---Used to track variables that are used between reusable method calls. This is required, because each
---call to the sources's completion hook won't create a new source object, but will reuse the same one.
---@class obsidian.completion.sources.base.RefsSourceCompletionContext : obsidian.ABC
---@field client obsidian.Client
---@field completion_resolve_callback (fun(self: any)) blink or nvim_cmp completion resolve callback
---@field request obsidian.completion.sources.base.Request
---@field in_buffer_only boolean
---@field search string|?
---@field insert_start integer|?
---@field insert_end integer|?
---@field ref_type obsidian.completion.RefType|?
---@field block_link string|?
---@field anchor_link string|?
---@field new_text_to_option table<string, obsidian.completion.sources.blink.CompletionItem>
local RefsSourceCompletionContext = abc.new_class()

RefsSourceCompletionContext.new = function()
  return RefsSourceCompletionContext.init()
end

---@class obsidian.completion.sources.base.RefsSourceBase : obsidian.ABC
---@field incomplete_response table
---@field complete_response table
local RefsSourceBase = abc.new_class()

---@return obsidian.completion.sources.base.RefsSourceBase
RefsSourceBase.new = function()
  return RefsSourceBase.init()
end

RefsSourceBase.get_trigger_characters = completion.get_trigger_characters

---Sets up a new completion context that is used to pass around variables between completion source methods
---@param completion_resolve_callback (fun(self: any)) blink or nvim_cmp completion resolve callback
---@param request obsidian.completion.sources.base.Request
---@return obsidian.completion.sources.base.RefsSourceCompletionContext
function RefsSourceBase:new_completion_context(completion_resolve_callback, request)
  local completion_context = RefsSourceCompletionContext.new()

  -- Sets up the completion callback, which will be called when the (possibly incomplete) completion items are ready
  completion_context.completion_resolve_callback = completion_resolve_callback

  -- This request object will be used to determine the current cursor location and the text around it
  completion_context.request = request

  completion_context.client = assert(obsidian.get_client())

  completion_context.in_buffer_only = false

  return completion_context
end

--- Runs a generalized version of the complete (nvim_cmp) or get_completions (blink) methods
---@param cc obsidian.completion.sources.base.RefsSourceCompletionContext
function RefsSourceBase:process_completion(cc)
  if not self:can_complete_request(cc) then
    return
  end

  self:strip_links(cc)
  self:determine_buffer_only_search_scope(cc)

  if cc.in_buffer_only then
    local note = cc.client:current_note(0, { collect_anchor_links = true, collect_blocks = true })
    if note then
      self:process_search_results(cc, { note })
    else
      cc.completion_resolve_callback(self.incomplete_response)
    end
  else
    local search_ops = cc.client.search_defaults()
    search_ops.ignore_case = true

    cc.client:find_notes_async(cc.search, function(results)
      self:process_search_results(cc, results)
    end, {
      search = search_ops,
      notes = { collect_anchor_links = cc.anchor_link ~= nil, collect_blocks = cc.block_link ~= nil },
    })
  end
end

--- Returns whatever it's possible to complete the search and sets up the search related variables in cc
---@param cc obsidian.completion.sources.base.RefsSourceCompletionContext
---@return boolean success provides a chance to return early if the request didn't meet the requirements
function RefsSourceBase:can_complete_request(cc)
  local can_complete
  can_complete, cc.search, cc.insert_start, cc.insert_end, cc.ref_type = completion.can_complete(cc.request)

  if not (can_complete and cc.search ~= nil and #cc.search >= cc.client.opts.completion.min_chars) then
    cc.completion_resolve_callback(self.incomplete_response)
    return false
  end

  return true
end

---Collect matching block links.
---@param note obsidian.Note
---@param block_link string?
---@return obsidian.note.Block[]|?
function RefsSourceBase:collect_matching_blocks(note, block_link)
  ---@type obsidian.note.Block[]|?
  local matching_blocks
  if block_link then
    assert(note.blocks)
    matching_blocks = {}
    for block_id, block_data in pairs(note.blocks) do
      if vim.startswith("#" .. block_id, block_link) then
        table.insert(matching_blocks, block_data)
      end
    end

    if #matching_blocks == 0 then
      -- Unmatched, create a mock one.
      table.insert(matching_blocks, { id = util.standardize_block(block_link), line = 1 })
    end
  end

  return matching_blocks
end

---Collect matching anchor links.
---@param note obsidian.Note
---@param anchor_link string?
---@return obsidian.note.HeaderAnchor[]?
function RefsSourceBase:collect_matching_anchors(note, anchor_link)
  ---@type obsidian.note.HeaderAnchor[]|?
  local matching_anchors
  if anchor_link then
    assert(note.anchor_links)
    matching_anchors = {}
    for anchor, anchor_data in pairs(note.anchor_links) do
      if vim.startswith(anchor, anchor_link) then
        table.insert(matching_anchors, anchor_data)
      end
    end

    if #matching_anchors == 0 then
      -- Unmatched, create a mock one.
      table.insert(matching_anchors, { anchor = anchor_link, header = string.sub(anchor_link, 2), level = 1, line = 1 })
    end
  end

  return matching_anchors
end

--- Strips block and anchor links from the current search string
---@param cc obsidian.completion.sources.base.RefsSourceCompletionContext
function RefsSourceBase:strip_links(cc)
  cc.search, cc.block_link = util.strip_block_links(cc.search)
  cc.search, cc.anchor_link = util.strip_anchor_links(cc.search)

  -- If block link is incomplete, we'll match against all block links.
  if not cc.block_link and vim.endswith(cc.search, "#^") then
    cc.block_link = "#^"
    cc.search = string.sub(cc.search, 1, -3)
  end

  -- If anchor link is incomplete, we'll match against all anchor links.
  if not cc.anchor_link and vim.endswith(cc.search, "#") then
    cc.anchor_link = "#"
    cc.search = string.sub(cc.search, 1, -2)
  end
end

--- Determines whatever the in_buffer_only should be enabled
---@param cc obsidian.completion.sources.base.RefsSourceCompletionContext
function RefsSourceBase:determine_buffer_only_search_scope(cc)
  if (cc.anchor_link or cc.block_link) and string.len(cc.search) == 0 then
    -- Search over headers/blocks in current buffer only.
    cc.in_buffer_only = true
  end
end

---@param cc obsidian.completion.sources.base.RefsSourceCompletionContext
---@param results obsidian.Note[]
function RefsSourceBase:process_search_results(cc, results)
  assert(cc)
  assert(results)

  local completion_items = {}

  cc.new_text_to_option = {}

  for note in iter(results) do
    ---@cast note obsidian.Note

    local matching_blocks = self:collect_matching_blocks(note, cc.block_link)
    local matching_anchors = self:collect_matching_anchors(note, cc.anchor_link)

    if cc.in_buffer_only then
      self:update_completion_options(cc, nil, nil, matching_anchors, matching_blocks, note)
    else
      -- Collect all valid aliases for the note, including ID, title, and filename.
      ---@type string[]
      local aliases
      if not cc.in_buffer_only then
        aliases = util.tbl_unique { tostring(note.id), note:display_name(), unpack(note.aliases) }
        if note.title ~= nil then
          table.insert(aliases, note.title)
        end
      end

      for alias in iter(aliases) do
        self:update_completion_options(cc, alias, nil, matching_anchors, matching_blocks, note)
        local alias_case_matched = util.match_case(cc.search, alias)

        if
          alias_case_matched ~= nil
          and alias_case_matched ~= alias
          and not util.tbl_contains(note.aliases, alias_case_matched)
        then
          self:update_completion_options(cc, alias_case_matched, nil, matching_anchors, matching_blocks, note)
        end
      end

      if note.alt_alias ~= nil then
        self:update_completion_options(cc, note:display_name(), note.alt_alias, matching_anchors, matching_blocks, note)
      end
    end
  end

  for _, option in pairs(cc.new_text_to_option) do
    -- TODO: need a better label, maybe just the note's display name?
    ---@type string
    local label
    if cc.ref_type == completion.RefType.Wiki then
      label = string.format("[[%s]]", option.label)
    elseif cc.ref_type == completion.RefType.Markdown then
      label = string.format("[%s](…)", option.label)
    else
      error "not implemented"
    end

    table.insert(completion_items, {
      documentation = option.documentation,
      sortText = option.sort_text,
      label = label,
      kind = vim.lsp.protocol.CompletionItemKind.Reference,
      textEdit = {
        newText = option.new_text,
        range = {
          ["start"] = {
            line = cc.request.context.cursor.row - 1,
            character = cc.insert_start,
          },
          ["end"] = {
            line = cc.request.context.cursor.row - 1,
            character = cc.insert_end + 1,
          },
        },
      },
    })
  end

  cc.completion_resolve_callback(vim.tbl_deep_extend("force", self.complete_response, { items = completion_items }))
end

---@param cc obsidian.completion.sources.base.RefsSourceCompletionContext
---@param label string|?
---@param alt_label string|?
---@param note obsidian.Note
function RefsSourceBase:update_completion_options(cc, label, alt_label, matching_anchors, matching_blocks, note)
  ---@type { label: string|?, alt_label: string|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }[]
  local new_options = {}
  if matching_anchors ~= nil then
    for anchor in iter(matching_anchors) do
      table.insert(new_options, { label = label, alt_label = alt_label, anchor = anchor })
    end
  elseif matching_blocks ~= nil then
    for block in iter(matching_blocks) do
      table.insert(new_options, { label = label, alt_label = alt_label, block = block })
    end
  else
    if label then
      table.insert(new_options, { label = label, alt_label = alt_label })
    end

    -- Add all blocks and anchors, let cmp sort it out.
    for _, anchor_data in pairs(note.anchor_links or {}) do
      table.insert(new_options, { label = label, alt_label = alt_label, anchor = anchor_data })
    end
    for _, block_data in pairs(note.blocks or {}) do
      table.insert(new_options, { label = label, alt_label = alt_label, block = block_data })
    end
  end

  -- De-duplicate options relative to their `new_text`.
  for _, option in ipairs(new_options) do
    ---@type obsidian.config.LinkStyle
    local link_style
    if cc.ref_type == completion.RefType.Wiki then
      link_style = LinkStyle.wiki
    elseif cc.ref_type == completion.RefType.Markdown then
      link_style = LinkStyle.markdown
    else
      error "not implemented"
    end

    ---@type string, string, string, table|?
    local final_label, sort_text, new_text, documentation
    if option.label then
      new_text = cc.client:format_link(
        note,
        { label = option.label, link_style = link_style, anchor = option.anchor, block = option.block }
      )

      final_label = assert(option.alt_label or option.label)
      if option.anchor then
        final_label = final_label .. option.anchor.anchor
      elseif option.block then
        final_label = final_label .. "#" .. option.block.id
      end
      sort_text = final_label

      documentation = {
        kind = "markdown",
        value = note:display_info {
          label = new_text,
          anchor = option.anchor,
          block = option.block,
        },
      }
    elseif option.anchor then
      -- In buffer anchor link.
      -- TODO: allow users to customize this?
      if cc.ref_type == completion.RefType.Wiki then
        new_text = "[[#" .. option.anchor.header .. "]]"
      elseif cc.ref_type == completion.RefType.Markdown then
        new_text = "[#" .. option.anchor.header .. "](" .. option.anchor.anchor .. ")"
      else
        error "not implemented"
      end

      final_label = option.anchor.anchor
      sort_text = final_label

      documentation = {
        kind = "markdown",
        value = string.format("`%s`", new_text),
      }
    elseif option.block then
      -- In buffer block link.
      -- TODO: allow users to customize this?
      if cc.ref_type == completion.RefType.Wiki then
        new_text = "[[#" .. option.block.id .. "]]"
      elseif cc.ref_type == completion.RefType.Markdown then
        new_text = "[#" .. option.block.id .. "](#" .. option.block.id .. ")"
      else
        error "not implemented"
      end

      final_label = "#" .. option.block.id
      sort_text = final_label

      documentation = {
        kind = "markdown",
        value = string.format("`%s`", new_text),
      }
    else
      error "should not happen"
    end

    if cc.new_text_to_option[new_text] then
      cc.new_text_to_option[new_text].sort_text = cc.new_text_to_option[new_text].sort_text .. " " .. sort_text
    else
      cc.new_text_to_option[new_text] =
        { label = final_label, new_text = new_text, sort_text = sort_text, documentation = documentation }
    end
  end
end

return RefsSourceBase
