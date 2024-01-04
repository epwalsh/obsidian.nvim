require("mini.doc").setup {}

local module_name = "obsidian"

local visual_text_width = function(text)
  -- Ignore concealed characters (usually "invisible" in 'help' filetype)
  local _, n_concealed_chars = text:gsub("([*|`])", "%1")
  return vim.fn.strdisplaywidth(text) - n_concealed_chars
end

local align_text = function(text, width, direction)
  if type(text) ~= "string" then
    return
  end
  text = vim.trim(text)
  width = width or 78
  direction = direction or "left"

  -- Don't do anything if aligning left or line is a whitespace
  if direction == "left" or text:find "^%s*$" then
    return text
  end

  local n_left = math.max(0, 78 - visual_text_width(text))
  if direction == "center" then
    n_left = math.floor(0.5 * n_left)
  end

  return (" "):rep(n_left) .. text
end

MiniDoc.generate({ "lua/obsidian/client.lua" }, "doc/obsidian_api.txt", {
  hooks = {
    sections = {
      ["@tag"] = function(s)
        for i, _ in ipairs(s) do
          -- Enclose every word in `*` and prepend module name.
          s[i] = s[i]:gsub("(%S+)", "%*" .. module_name .. ".%1%*")

          -- Align to right edge accounting for concealed characters
          s[i] = align_text(s[i], 78, "right")
        end
      end,
    },
  },
})
