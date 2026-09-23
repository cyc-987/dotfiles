-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- 拷贝当前文件的【相对路径】到 Mac 剪贴板（普通模式下按 <Space> + c + r）
vim.keymap.set("n", "<leader>cr", function()
  local path = vim.fn.expand("%")
  vim.fn.setreg("+", path)
  vim.notify('Copied relative path: "' .. path .. '"')
end, { desc = "Copy relative path to clipboard" })

-- 拷贝当前文件的【绝对路径】到 Mac 剪贴板（普通模式下按 <Space> + c + p）
vim.keymap.set("n", "<leader>cp", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify('Copied full path: "' .. path .. '"')
end, { desc = "Copy full path to clipboard" })
