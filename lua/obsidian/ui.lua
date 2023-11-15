local util = require "obsidian.util"
local throttle = require("obsidian.async").throttle

local M = {}

local Groups = {
  todo = "ObsidianTodo",
  done = "ObsidianDone",
  right_arrow = "ObsidianRightArrow",
  tilde = "ObsidianTilde",
  ref = "ObsidianRef",
  url_marker = "ObsidianUrlMarker",
}

---@param ui_opts obsidian.config.UIOpts
M.install_hl_groups = function(ui_opts)
  vim.api.nvim_set_hl(0, Groups.todo, { bold = true, fg = ui_opts.colors.todo_box })
  vim.api.nvim_set_hl(0, Groups.done, { bold = true, fg = ui_opts.colors.done_box })
  vim.api.nvim_set_hl(0, Groups.right_arrow, { bold = true, fg = ui_opts.colors.right_arrow_box })
  vim.api.nvim_set_hl(0, Groups.tilde, { bold = true, fg = ui_opts.colors.tilde_box })
  vim.api.nvim_set_hl(0, Groups.ref, { underline = true, fg = ui_opts.colors.ref })
  vim.api.nvim_set_hl(0, Groups.url_marker, { fg = ui_opts.colors.ref })
end

---@param bufnr integer
---@param line string
---@param lnum integer
---@param ui_opts obsidian.config.UIOpts
local function update_line_check_extmarks(bufnr, ns_id, line, lnum, ui_opts)
  if string.match(line, "^%s*- %[ %]") then
    -- This is an empty checkbox '- [ ]'
    local indent = util.count_indent(line)
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, indent, {
      end_row = lnum,
      end_col = indent + 5,
      conceal = ui_opts.chars.todo_box,
      hl_group = Groups.todo,
    })
  elseif string.match(line, "^%s*- %[x%]") then
    -- This is a checked box '- [x]'
    local indent = util.count_indent(line)
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, indent, {
      end_row = lnum,
      end_col = indent + 5,
      conceal = ui_opts.chars.done_box,
      hl_group = Groups.done,
    })
  elseif string.match(line, "^%s*- %[>%]") then
    -- This is a box with a right arrow '- [>]'
    local indent = util.count_indent(line)
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, indent, {
      end_row = lnum,
      end_col = indent + 5,
      conceal = ui_opts.chars.right_arrow_box,
      hl_group = Groups.right_arrow,
    })
  elseif string.match(line, "^%s*- %[~%]") then
    -- This is a box with a tilde '- [~]'
    local indent = util.count_indent(line)
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, indent, {
      end_row = lnum,
      end_col = indent + 5,
      conceal = ui_opts.chars.tilde_box,
      hl_group = Groups.tilde,
    })
  end
end

---@param bufnr integer
---@param line string
---@param lnum integer
---@param ui_opts obsidian.config.UIOpts
local function update_line_ref_extmarks(bufnr, ns_id, line, lnum, ui_opts)
  local matches = util.find_refs(line)
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
        hl_group = Groups.ref,
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
        hl_group = Groups.ref,
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
        hl_group = Groups.ref,
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
        conceal = is_url and ui_opts.chars.url or "",
        hl_group = Groups.url_marker,
      })
      -- Conceal the closing ')'
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, m_end - 1, {
        end_row = lnum,
        end_col = m_end,
        conceal = is_url and " " or "",
      })
    end
  end
end

---@param bufnr integer
---@param ui_opts obsidian.config.UIOpts
local function update_extmarks(bufnr, ns_id, ui_opts)
  -- Iterate over lines, updating marks.
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  for i, line in ipairs(lines) do
    local lnum = i - 1
    -- Remove existing marks.
    -- TODO: can we cache these instead and only update when needed?
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, lnum, lnum + 1)
    update_line_check_extmarks(bufnr, ns_id, line, lnum, ui_opts)
    update_line_ref_extmarks(bufnr, ns_id, line, lnum, ui_opts)
  end
end

---@param ui_opts obsidian.config.UIOpts
---@return function
M.get_autocmd_callback = function(ui_opts)
  local ns_id = vim.api.nvim_create_namespace "obsidian"
  M.install_hl_groups(ui_opts)
  return throttle(function(ev)
    update_extmarks(ev.buf, ns_id, ui_opts)
  end, ui_opts.tick)
end

return M
