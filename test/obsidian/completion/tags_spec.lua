local completion = require "obsidian.completion.tags"

describe("find_tags_start()", function()
  it("should find tags within line", function()
    assert.are_same("tag", completion.find_tags_start "Foo bar #tag")
  end)

  it("should find tags at the beginning of a line", function()
    assert.are_same("tag", completion.find_tags_start "#tag")
  end)

  it("should ignore anchor links", function()
    assert.is_nil(completion.find_tags_start "[[#header")
    assert.is_nil(completion.find_tags_start "[[Bar#header")
  end)
end)
