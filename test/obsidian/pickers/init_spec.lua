local config = require "obsidian.config"
local pickers = require "obsidian.pickers"

describe("Picker registry", function()
  local mock_client

  before_each(function()
    -- Create a minimal mock client
    mock_client = {
      dir = vim.fn.getcwd(),
      opts = {
        picker = {
          name = nil,
        },
      },
    }
  end)

  it("should load snacks picker when explicitly requested", function()
    -- This test will only pass if snacks.nvim is installed
    -- So we make it conditional
    local has_snacks = pcall(require, "snacks")
    if has_snacks then
      local ok, picker = pcall(pickers.get, mock_client, config.Picker.snacks)
      assert.is_true(ok)
      assert.is_not_nil(picker)
      assert.equals("SnacksPicker()", tostring(picker))
    else
      -- Skip test if snacks not available
      pending("snacks.nvim not installed")
    end
  end)

  it("should recognize snacks in the Picker enum", function()
    assert.equals("snacks.nvim", config.Picker.snacks)
  end)

  it("should create snacks picker instance even when snacks not installed", function()
    -- The picker can be instantiated even when snacks.nvim is not available.
    -- Methods like find_files() will check for snacks at runtime and fail gracefully.
    local ok, picker = pcall(pickers.get, mock_client, config.Picker.snacks)
    assert.is_true(ok)
    assert.is_not_nil(picker)
    assert.equals("SnacksPicker()", tostring(picker))
  end)
end)
