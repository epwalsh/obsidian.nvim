local Path = require "obsidian.path"
local util = require "obsidian.util"
local paste_img = require("obsidian.img_paste").paste_img

---@param client obsidian.Client
return function(client, data)
  local img_folder = Path.new(client.opts.attachments.img_folder)
  if not img_folder:is_absolute() then
    img_folder = client.dir / client.opts.attachments.img_folder
  end

  ---@type string|?
  local default_name
  if client.opts.attachments.img_name_func then
    default_name = client.opts.attachments.img_name_func()
  end

  local path = paste_img {
    fname = data.args,
    default_dir = img_folder,
    relative_dir = client.opts.attachments.relative_dir,
    default_name = default_name,
    should_confirm = client.opts.attachments.confirm_img_paste,
  }

  if path ~= nil then
    util.insert_text(client.opts.attachments.img_text_func(client, path))
  end
end
