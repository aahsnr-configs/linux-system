-- ~/.config/nvim/lua/config/autocmds.lua
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Yank highlight
autocmd("TextYankPost", {
  group = augroup("YankHighlight", { clear = true }),
  callback = function() vim.highlight.on_yank() end,
})

-- Close utility buffers with q
autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = { "help", "lspinfo", "man", "notify", "qf", "checkhealth", "diffview", "neotree" },
  callback = function(e)
    vim.bo[e.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = e.buf, silent = true })
  end,
})

-- Academic writing mode (wrap + spell)
autocmd("FileType", {
  group = augroup("academic_mode", { clear = true }),
  pattern = { "markdown", "tex", "plaintex", "text", "gitcommit", "org" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.linebreak = true
    vim.opt_local.textwidth = 88
    vim.opt_local.colorcolumn = "0"
  end,
})

-- Auto-resize splits on terminal resize
autocmd("VimResized", {
  group = augroup("auto_resize", { clear = true }),
  callback = function() vim.api.nvim_command("tabdo wincmd =") end,
})
