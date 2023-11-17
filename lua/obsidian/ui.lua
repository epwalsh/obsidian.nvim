local util = require "obsidian.util"
local throttle = require("obsidian.async").throttle

local M = {}

---@param ui_opts obsidian.config.UIOpts
M.install_hl_groups = function(ui_opts)
  for group_name, opts in pairs(ui_opts.hl_groups) do
    vim.api.nvim_set_hl(0, group_name, opts)
  end
end

---@param bufnr integer
---@param line string
---@param lnum integer
---@param ui_opts obsidian.config.UIOpts
local function update_line_check_extmarks(bufnr, ns_id, line, lnum, ui_opts)
  for char, opts in pairs(ui_opts.checkboxes) do
    -- TODO: escape `char` if needed
    if string.match(line, "^%s*- %[" .. char .. "%]") then
      local indent = util.count_indent(line)
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, indent, {
        end_row = lnum,
        end_col = indent + 5,
        conceal = opts.char,
        hl_group = opts.hl_group,
      })
      break
    end
  end
end

---@param bufnr integer
---@param line string
---@param lnum integer
---@param ui_opts obsidian.config.UIOpts
local function update_line_ref_extmarks(bufnr, ns_id, line, lnum, ui_opts)
  local matches = util.find_refs(line, true)
  for match in util.iter(matches) do
    local m_start, m_end, m_type = unpack(match)
    if m_type == util.RefTypes.WikiWithAlias then
      -- Reference of the form [[xxx|yyy]]
      local pipe_loc = string.find(line, "|", m_start, true)
      assert(pipe_loc)
      -- Conceal everything from '[[' up to '|'
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_start - 1, {
        end_row = lnum,
        end_col = pipe_loc,
        conceal = "",
      })
      -- Highlight the alias 'yyy'
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, pipe_loc, {
        end_row = lnum,
        end_col = m_end - 2,
        hl_group = ui_opts.reference_text.hl_group,
        spell = false,
      })
      -- Conceal the closing ']]'
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_end - 1, {
        end_row = lnum,
        end_col = m_end,
        conceal = "",
      })
    elseif m_type == util.RefTypes.Wiki then
      -- Reference of the form [[xxx]]
      -- Conceal the opening '[['
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_start - 1, {
        end_row = lnum,
        end_col = m_start + 1,
        conceal = "",
      })
      -- Highlight the ref 'xxx'
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_start + 1, {
        end_row = lnum,
        end_col = m_end - 2,
        hl_group = ui_opts.reference_text.hl_group,
        spell = false,
      })
      -- Conceal the closing ']]'
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_end - 1, {
        end_row = lnum,
        end_col = m_end,
        conceal = "",
      })
    elseif m_type == util.RefTypes.Markdown then
      -- Reference of the form [yyy](xxx)
      local closing_bracket_loc = string.find(line, "]", m_start, true)
      assert(closing_bracket_loc)
      local is_url = util.is_url(string.sub(line, closing_bracket_loc + 2, m_end - 1))
      -- Conceal the opening '['
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_start - 1, {
        end_row = lnum,
        end_col = m_start,
        conceal = "",
      })
      -- Highlight the ref 'yyy'
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_start, {
        end_row = lnum,
        end_col = closing_bracket_loc - 1,
        hl_group = ui_opts.reference_text.hl_group,
        spell = false,
      })
      -- Conceal the ']('
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, closing_bracket_loc - 1, {
        end_row = lnum,
        end_col = closing_bracket_loc + 1,
        conceal = is_url and " " or "",
      })
      -- Conceal the URL part 'xxx' with the external URL character
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, closing_bracket_loc + 1, {
        end_row = lnum,
        end_col = m_end - 1,
        conceal = is_url and ui_opts.external_link_icon.char or "",
        hl_group = ui_opts.external_link_icon.hl_group,
      })
      -- Conceal the closing ')'
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_end - 1, {
        end_row = lnum,
        end_col = m_end,
        conceal = is_url and " " or "",
      })
    elseif m_type == util.RefTypes.NakedUrl then
      -- A "naked" URL is just a URL by itself, like 'https://github.com/'
      local domain_start_loc = string.find(line, "://", m_start, true)
      assert(domain_start_loc)
      domain_start_loc = domain_start_loc + 3
      -- Conceal the "https?://" part
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_start - 1, {
        end_row = lnum,
        end_col = domain_start_loc - 1,
        conceal = "",
      })
      -- Highlight the whole thing.
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_start - 1, {
        end_row = lnum,
        end_col = m_end,
        hl_group = ui_opts.reference_text.hl_group,
        spell = false,
      })
    end
  end
end

---@param bufnr integer
---@param ui_opts obsidian.config.UIOpts
local function update_extmarks(bufnr, ns_id, ui_opts)
  local inside_code_block = false
  -- Iterate over lines (skipping code blocks) and update marks.
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  for i, line in ipairs(lines) do
    local lnum = i - 1
    -- Remove existing marks.
    -- TODO: can we cache these instead and only update when needed?
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, lnum, lnum + 1)
    -- Check if inside a code block or at code block boundary. If not, update marks.
    if string.match(line, "^%s*```[^`]*$") then
      inside_code_block = not inside_code_block
    elseif not inside_code_block then
      update_line_check_extmarks(bufnr, ns_id, line, lnum, ui_opts)
      update_line_ref_extmarks(bufnr, ns_id, line, lnum, ui_opts)
    end
  end
end

---@param ui_opts obsidian.config.UIOpts
---@return function
M.get_autocmd_callback = function(ui_opts)
  local ns_id = vim.api.nvim_create_namespace "obsidian"
  M.install_hl_groups(ui_opts)
  return throttle(function(ev)
    update_extmarks(ev.buf, ns_id, ui_opts)
  end, ui_opts.update_debounce)
end

return M
