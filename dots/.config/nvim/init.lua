vim.g.mapleader = " " -- Set global leader to Space
vim.g.maplocalleader = " " -- Set local leader to Space

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim" -- Path to lazy.nvim installation
if not vim.loop.fs_stat(lazypath) then -- Bootstrap lazy.nvim if not already installed
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath }) -- Clone latest stable release
end -- End bootstrap check
vim.opt.rtp:prepend(lazypath) -- Add lazy.nvim to runtimepath

require("lazy").setup({ -- Initialize plugin manager and import plugin modules
  { import = "plugins.ui" }, -- UI plugins (colorscheme, statusline, bufferline, etc.)
  { import = "plugins.editor" }, -- Editor plugins (treesitter, telescope, autopairs, etc.)
  { import = "plugins.lsp" }, -- LSP plugins (mason, lspconfig, none-ls, etc.)
  { import = "plugins.completion" }, -- Completion plugins (cmp, luasnip, etc.)
  { import = "plugins.git" }, -- Git plugins (gitsigns, fugitive, diffview, etc.)
  { import = "plugins.tools" }, -- Tool plugins (harpoon, oil, toggleterm, render-markdown, etc.)
}, { -- Lazy.nvim configuration options
  checker = { enabled = true }, -- Automatically check for plugin updates
  change_detection = { notify = false }, -- Disable config reload notifications
}) -- End lazy.setup

require("core.options") -- Load general Neovim options
require("core.keymaps") -- Load key mappings
require("core.autocmds") -- Load autocommands (format-on-save, etc.)
