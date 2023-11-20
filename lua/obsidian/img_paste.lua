local Path = require "plenary.path"
local util = require "obsidian.util"
local log = require "obsidian.log"
local run_job = require("obsidian.async").run_job

local M = {}

-- Image pasting adapted from https://github.com/ekickx/clipboard-image.nvim

---@return string
local function get_clip_check_command()
  local check_cmd
  local this_os = util.get_os()
  if this_os == util.OSType.Linux then
    local display_server = os.getenv "XDG_SESSION_TYPE"
    if display_server == "x11" or display_server == "tty" then
      check_cmd = "xclip -selection clipboard -o -t TARGETS"
    elseif display_server == "wayland" then
      check_cmd = "wl-paste --list-types"
    end
  elseif this_os == util.OSType.Darwin then
    check_cmd = "pngpaste -b 2>&1"
  elseif this_os == util.OSType.Windows or this_os == util.OSType.Wsl then
    check_cmd = 'powershell.exe "Get-Clipboard -Format Image"'
  else
    log.fail("image saving not implemented for OS '" .. this_os .. "'")
  end
  return check_cmd
end

---Check if clipboard contains image data.
---@return boolean
local function clipboard_is_img()
  local content = {}
  for output in assert(io.popen(get_clip_check_command())):lines() do
    content[#content + 1] = output
  end

  -- See: [Data URI scheme](https://en.wikipedia.org/wiki/Data_URI_scheme)
  local this_os = util.get_os()
  if this_os == util.OSType.Linux then
    return vim.tbl_contains(content, "image/png")
  elseif this_os == util.OSType.Darwin then
    return string.sub(content[1], 1, 9) == "iVBORw0KG" -- Magic png number in base64
  elseif this_os == util.OSType.Windows or this_os == util.OSType.Wsl then
    return content ~= nil
  else
    log.fail("image saving not implemented for OS '" .. this_os .. "'")
    return false
  end
end

---Save image from clipboard to `path`.
---@param path string
---@return boolean|integer|? result
local function save_clipboard_image(path)
  local this_os = util.get_os()

  if this_os == util.OSType.Linux then
    local cmd
    local display_server = os.getenv "XDG_SESSION_TYPE"
    if display_server == "x11" or display_server == "tty" then
      cmd = string.format("xclip -selection clipboard -t image/png -o > '%s'", path)
    elseif display_server == "wayland" then
      cmd = string.format("wl-paste --no-newline --type image/png > '%s'", path)
    end

    local result = os.execute(cmd)
    if type(result) == "number" and result > 0 then
      return false
    else
      return result
    end
  elseif this_os == util.OSType.Windows or this_os == util.OSType.Wsl then
    local cmd = 'powershell.exe "'
      .. string.format(
        "$content = Get-Clipboard -Format Image;$content.Save('%s', 'png')",
        string.gsub(path, "/", "\\")
      )
      .. '"'
    return os.execute(cmd)
  elseif this_os == util.OSType.Darwin then
    return run_job("pngpaste", { path })
  else
    return log.fail("image saving not implemented for OS '" .. this_os .. "'")
  end
end

---@param fname string|?
---@param default_dir Path|string
---@return Path|? image_path the absolute path to the image file
M.paste_img = function(fname, default_dir)
  if not clipboard_is_img() then
    log.err "There is no image data in the clipboard"
    return
  else
    -- Get filename to save to.
    if fname == "" then
      fname = vim.fn.input { prompt = "Enter file name: " }
    end

    if fname == "" then
      log.err "Invalid file name"
      return
    end

    -- Make sure fname ends with ".png"
    if not vim.endswith(fname, ".png") then
      fname = fname .. ".png"
    end

    -- Resolve path to paste image to.
    local path
    if vim.fs.basename(fname) ~= fname then
      -- fname is a full path
      path = Path:new(fname)
    else
      path = Path:new(default_dir) / fname
    end
    path = Path:new(path:absolute())

    -- Get confirmation from user.
    local confirmation = string.lower(vim.fn.input {
      prompt = "Saving image to '" .. tostring(path) .. "'. Do you want to continue? [Y/n] ",
    })
    if not (confirmation == "y" or confirmation == "yes") then
      log.warn "Paste canceled"
      return
    end

    -- Ensure parent directory exists.
    path:parent():mkdir { exists_ok = true, parents = true }

    -- Paste image.
    local result = save_clipboard_image(tostring(path))
    if result == false then
      log.err "Failed to save image"
      return
    end

    return path
  end
end

return M
