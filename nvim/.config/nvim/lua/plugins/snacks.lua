local function get_picker(p)
  if p and type(p.selected) == "function" then
    return p
  end
  local pickers = Snacks.picker.get({ source = "explorer" })
  if pickers and #pickers > 0 then
    return pickers[1]
  end
  pickers = Snacks.picker.get()
  return pickers and pickers[1] or nil
end

local function yank_relative(p)
  local picker = get_picker(p)
  if not picker then
    return
  end
  local files = {}
  if vim.fn.mode():find("^[vV]") then
    picker.list:select()
  end
  for _, item in ipairs(picker:selected({ fallback = true })) do
    local path = item.file or (item.dir and item.path) or Snacks.picker.util.path(item)
    if path then
      local rel = vim.fn.fnamemodify(path, ":.")
      table.insert(files, rel == "" and "." or rel)
    end
  end
  picker.list:set_selected()
  local value = table.concat(files, "\n")
  vim.fn.setreg("+", value)
  Snacks.notify.info("Copied relative path:\n" .. value)
end

local function yank_full(p)
  local picker = get_picker(p)
  if not picker then
    return
  end
  local files = {}
  if vim.fn.mode():find("^[vV]") then
    picker.list:select()
  end
  for _, item in ipairs(picker:selected({ fallback = true })) do
    local path = item.file or (item.dir and item.path) or Snacks.picker.util.path(item)
    if path then
      table.insert(files, path)
    end
  end
  picker.list:set_selected()
  local value = table.concat(files, "\n")
  vim.fn.setreg("+", value)
  Snacks.notify.info("Copied full path:\n" .. value)
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      actions = {
        explorer_yank_relative = yank_relative,
        explorer_yank_full = yank_full,
      },
      sources = {
        explorer = {
          win = {
            list = {
              keys = {
                ["y"] = { "explorer_yank_relative", mode = { "n", "x" } },
                ["Y"] = { "explorer_yank_full", mode = { "n", "x" } },
              },
            },
          },
        },
      },
    },
  },
}
