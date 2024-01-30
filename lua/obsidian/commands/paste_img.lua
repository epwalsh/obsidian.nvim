local Path = require "plenary.path"
local util = require "obsidian.util"
local paste_img = require("obsidian.img_paste").paste_img

---@param client obsidian.Client
return function(client, data)
  local img_folder = Path:new(client.opts.attachments.img_folder)
  if not img_folder:is_absolute() then
    img_folder = client.dir / client.opts.attachments.img_folder
  end

  ---@type string|?
  local default_name
  if client.opts.image_name_func then
    default_name = client.opts.image_name_func()
  end

  local path = paste_img(data.args, img_folder, default_name)

  if path ~= nil then
    util.insert_text(client.opts.attachments.img_text_func(client, path))
  end
end
