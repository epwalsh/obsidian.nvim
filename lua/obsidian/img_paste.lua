local Path = require "plenary.path"
local util = require "obsidian.util"
local echo = require "obsidian.echo"

local M = {}

-- Image pasting adapted from https://github.com/ekickx/clipboard-image.nvim

---Check if clipboard contain image data
---See also: [Data URI scheme](https://en.wikipedia.org/wiki/Data_URI_scheme)
---@param content string[]
---@return boolean
local function is_clipboard_img(content)
  local this_os = util.get_os()
  if this_os == util.OSType.Linux then
    return vim.tbl_contains(content, "image/png")
  elseif this_os == util.OSType.Darwin then
    return string.sub(content[1], 1, 9) == "iVBORw0KG" -- Magic png number in base64
  else
    error("not implemented for OS '" .. this_os .. "'")
  end
end

---@return string, string
local function get_clip_command()
  local cmd_check, cmd_paste = "", ""
  local this_os = util.get_os()
  if this_os == util.OSType.Linux then
    local display_server = os.getenv "XDG_SESSION_TYPE"
    if display_server == "x11" or display_server == "tty" then
      cmd_check = "xclip -selection clipboard -o -t TARGETS"
      cmd_paste = "xclip -selection clipboard -t image/png -o > '%s'"
    elseif display_server == "wayland" then
      cmd_check = "wl-paste --list-types"
      cmd_paste = "wl-paste --no-newline --type image/png > '%s'"
    end
  elseif this_os == util.OSType.Darwin then
    cmd_check = "pngpaste -b 2>&1"
    cmd_paste = "pngpaste '%s'"
  elseif this_os == util.OSType.Windows or this_os == util.OSType.Wsl then
    cmd_check = "Get-Clipboard -Format Image"
    cmd_paste = "$content = " .. cmd_check .. ";$content.Save('%s', 'png')"
    cmd_check = 'powershell.exe "' .. cmd_check .. '"'
    cmd_paste = 'powershell.exe "' .. cmd_paste .. '"'
  end
  return cmd_check, cmd_paste
end

---@param command string
---@return string[]
local function get_clip_content(command)
  local cmd = assert(io.popen(command))
  local outputs = {}

  -- Store output in outputs table
  for output in cmd:lines() do
    table.insert(outputs, output)
  end

  return outputs
end

---@param fname string|?
---@param default_dir Path|string
---@return Path|?
M.paste_img = function(fname, default_dir)
  local cmd_check, cmd_paste = get_clip_command()
  local content = get_clip_content(cmd_check)
  if not is_clipboard_img(content) then
    echo.err "There is no image data in the clipboard"
    return
  else
    -- Get filename to save to.
    if fname == "" then
      fname = vim.fn.input { prompt = "Enter file name: " }
    end

    if fname == "" then
      echo.err "Invalid file name"
      return
    end

    -- Make sure fname ends with ".png"
    if not vim.endswith(fname, ".png") then
      fname = fname .. ".png"
    end

    -- Resolve path to paste image to.
    local path
    if string.find(fname, "/", nil, true) ~= nil then
      path = Path:new(fname)
    else
      path = Path:new(default_dir) / fname
    end

    -- Get confirmation from user.
    local confirmation = string.lower(vim.fn.input {
      prompt = "Saving image to '" .. tostring(path:absolute()) .. "'. Do you want to continue? [Y/n] ",
    })
    if not (confirmation == "y" or confirmation == "yes") then
      echo.warn "Paste canceled"
      return
    end

    -- Ensure parent directory exists.
    path:parent():mkdir { exists_ok = true, parents = true }

    -- Paste image.
    os.execute(string.format(cmd_paste, tostring(path)))

    return path
  end
end

return M
