-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.autoformat = false

-- 检测 SSH 环境（包含 tmux 中只传递 SSH_CONNECTION 的情况）
if vim.env.SSH_TTY or vim.env.SSH_CLIENT or vim.env.SSH_CONNECTION then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end

-- 覆盖 LazyVim 在 SSH 下默认禁用 clipboard 的策略，使 yy/p 同步到系统剪贴板
vim.opt.clipboard = "unnamedplus"
