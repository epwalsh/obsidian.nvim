local ui = require "obsidian.ui"

describe("ExtMark", function()
  it("should match == with other ExtMark instances", function()
    local m1 = ui.ExtMark.new(
      nil,
      1,
      0,
      ui.ExtMarkOpts.from_tbl {
        end_row = 1,
        end_col = 2,
        conceal = "",
      }
    )
    local m2 = ui.ExtMark.new(
      0,
      1,
      0,
      ui.ExtMarkOpts.from_tbl {
        end_row = 1,
        end_col = 2,
        conceal = "",
      }
    )
    assert(m1 == m2)

    m1 = ui.ExtMark.new(
      nil,
      58,
      2,
      ui.ExtMarkOpts.from_tbl {
        end_row = 58,
        end_col = 29,
        conceal = "",
      }
    )
    m2 = ui.ExtMark.new(
      62,
      58,
      2,
      ui.ExtMarkOpts.from_tbl {
        end_row = 58,
        end_col = 29,
        conceal = "",
      }
    )
    assert(m1 == m2)
  end)
end)
