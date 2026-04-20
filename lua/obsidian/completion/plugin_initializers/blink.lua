local util = require "obsidian.util"
local obsidian = require "obsidian"

local M = {}

M.injected_once = false

M.providers = {
  { name = "obsidian", module = "obsidian.completion.sources.blink.refs" },
  { name = "obsidian_tags", module = "obsidian.completion.sources.blink.tags" },
  { name = "obsidian_new", module = "obsidian.completion.sources.blink.new" },
}

local function add_provider(blink, provider_name, proivder_module)
  local add_source_provider = blink.add_source_provider or blink.add_provider
  add_source_provider(provider_name, {
    name = provider_name,
    module = proivder_module,
    async = true,
    opts = {},
    enabled = function()
      -- Enable only in markdown buffers.
      return vim.tbl_contains({ "markdown" }, vim.bo.filetype)
        and vim.bo.buftype ~= "prompt"
        and vim.b.completion ~= false
    end,
  })
end

-- Ran once on the plugin startup
function M.register_providers()
  local blink = require "blink.cmp"

  for _, provider in pairs(M.providers) do
    add_provider(blink, provider.name, provider.module)
  end
end

local function add_element_to_list_if_not_exists(list, element)
  if not vim.tbl_contains(list, element) then
    table.insert(list, 1, element)
  end
end

local function should_return_if_not_in_workspace()
  local current_file_path = vim.api.nvim_buf_get_name(0)
  local buf_dir = vim.fs.dirname(current_file_path)

  local obsidian_client = assert(obsidian.get_client())
  local workspace = obsidian.Workspace.get_workspace_for_dir(buf_dir, obsidian_client.opts.workspaces)
  if not workspace then
    return true
  else
    return false
  end
end

local function log_unexpected_type(config_path, unexpected_type, expected_type)
  vim.notify(
    "blink.cmp's `"
      .. config_path
      .. "` configuration appears to be an '"
      .. unexpected_type
      .. "' type, but it "
      .. "should be '"
      .. expected_type
      .. "'. Obsidian won't update this configuration, and "
      .. "completion won't work with blink.cmp",
    vim.log.levels.ERROR
  )
end

---Attempts to inject the Obsidian sources into per_filetype if that's what the user seems to use for markdown
---@param blink_sources_per_filetype table<string, (fun():string[])|(string[])>
---@return boolean true if it obsidian sources were injected into the sources.per_filetype
local function try_inject_blink_sources_into_per_filetype(blink_sources_per_filetype)
  -- If the per_filetype is an empty object, then it's probably not utilized by the user
  if vim.deep_equal(blink_sources_per_filetype, {}) then
    return false
  end

  local markdown_config = blink_sources_per_filetype["markdown"]

  -- If the markdown key is not used, then per_filetype it's probably not utilized by the user
  if markdown_config == nil then
    return false
  end

  local markdown_config_type = type(markdown_config)
  if markdown_config_type == "table" and util.tbl_is_array(markdown_config) then
    for _, provider in pairs(M.providers) do
      add_element_to_list_if_not_exists(markdown_config, provider.name)
    end
    return true
  elseif markdown_config_type == "function" then
    local original_func = markdown_config
    markdown_config = function()
      local original_results = original_func()

      if should_return_if_not_in_workspace() then
        return original_results
      end

      for _, provider in pairs(M.providers) do
        add_element_to_list_if_not_exists(original_results, provider.name)
      end
      return original_results
    end

    -- Overwrite the original config function with the newly generated one
    require("blink.cmp.config").sources.per_filetype["markdown"] = markdown_config
    return true
  else
    log_unexpected_type(
      ".sources.per_filetype['markdown']",
      markdown_config_type,
      "a list or a function that returns a list of sources"
    )
    return true -- logged the error, returns as if this was successful to avoid further errors
  end
end

---Attempts to inject the Obsidian sources into default if that's what the user seems to use for markdown
---@param blink_sources_default (fun():string[])|(string[])
---@return boolean true if it obsidian sources were injected into the sources.default
local function try_inject_blink_sources_into_default(blink_sources_default)
  local blink_default_type = type(blink_sources_default)
  if blink_default_type == "function" then
    local original_func = blink_sources_default
    blink_sources_default = function()
      local original_results = original_func()

      if should_return_if_not_in_workspace() then
        return original_results
      end

      for _, provider in pairs(M.providers) do
        add_element_to_list_if_not_exists(original_results, provider.name)
      end
      return original_results
    end

    -- Overwrite the original config function with the newly generated one
    require("blink.cmp.config").sources.default = blink_sources_default
    return true
  elseif blink_default_type == "table" and util.tbl_is_array(blink_sources_default) then
    for _, provider in pairs(M.providers) do
      add_element_to_list_if_not_exists(blink_sources_default, provider.name)
    end

    return true
  elseif blink_default_type == "table" then
    log_unexpected_type(".sources.default", blink_default_type, "a list")
    return true -- logged the error, returns as if this was successful to avoid further errors
  else
    log_unexpected_type(".sources.default", blink_default_type, "a list or a function that returns a list")
    return true -- logged the error, returns as if this was successful to avoid further errors
  end
end

-- Triggered for each opened markdown buffer that's in a workspace. nvm_cmp had the capability to configure the sources
-- per buffer, but blink.cmp doesn't have that capability. Instead, we have to inject the sources into the global
-- configuration and set a boolean on the module to return early the next time this function is called.
--
-- In-case the user used functions to configure their sources, the completion will properly work just for the markdown
-- files that are in a workspace. Otherwise, the completion will work for all markdown files.
function M.inject_sources()
  if M.injected_once then
    return
  end

  M.injected_once = true

  local blink_config = require "blink.cmp.config"
  -- 'per_filetype' sources has priority over 'default' sources.
  -- 'per_filetype' can be a table or a function which returns a table (["filetype"] = { "a", "b" })
  -- 'per_filetype' has the default value of {} (even if it's not configured by the user)
  local blink_sources_per_filetype = blink_config.sources.per_filetype
  if try_inject_blink_sources_into_per_filetype(blink_sources_per_filetype) then
    return
  end

  -- 'default' can be a list/array or a function which returns a list/array ({ "a", "b"})
  local blink_sources_default = blink_config.sources["default"]
  if try_inject_blink_sources_into_default(blink_sources_default) then
    return
  end
end

return M
