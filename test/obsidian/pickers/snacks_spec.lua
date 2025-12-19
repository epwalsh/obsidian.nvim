local abc = require "obsidian.abc"
local Picker = require "obsidian.pickers.picker"

describe("SnacksPicker", function()
  it("should load without errors", function()
    local ok, SnacksPicker = pcall(require, "obsidian.pickers._snacks")
    assert.is_true(ok)
    assert.is_not_nil(SnacksPicker)
  end)

  it("should be a subclass of Picker", function()
    local SnacksPicker = require "obsidian.pickers._snacks"
    -- Check that SnacksPicker has the Picker methods
    assert.is_function(SnacksPicker.find_files)
    assert.is_function(SnacksPicker.grep)
    assert.is_function(SnacksPicker.pick)
    assert.is_function(SnacksPicker.find_notes)
    assert.is_function(SnacksPicker.grep_notes)
    assert.is_function(SnacksPicker.pick_note)
    assert.is_function(SnacksPicker.pick_tag)
  end)

  it("should have a proper __tostring", function()
    local SnacksPicker = require "obsidian.pickers._snacks"
    local picker = SnacksPicker.init()
    assert.equals("SnacksPicker()", tostring(picker))
  end)
end)
