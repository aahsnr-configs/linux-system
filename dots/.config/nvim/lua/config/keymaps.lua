-- ~/.config/nvim/lua/config/keymaps.lua
local map = vim.keymap.set
local silent = { noremap = true, silent = true }

-- General
map("n", "<leader>w", "<cmd>w<CR>", silent)
map("n", "<leader>q", "<cmd>q<CR>", silent)
map("n", "<leader>W", "<cmd>wa<CR>", silent)
map("n", "<leader>Q", "<cmd>qa!<CR>", silent)

-- Windows & Buffers
map("n", "<leader>h", "<C-w>h", silent)
map("n", "<leader>j", "<C-w>j", silent)
map("n", "<leader>k", "<C-w>k", silent)
map("n", "<leader>l", "<C-w>l", silent)
map("n", "<leader>\\", "<C-w>v", silent)
map("n", "<leader>-", "<C-w>s", silent)
map("n", "<leader>bd", "<cmd>bd<CR>", silent)
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<CR>", silent)

-- Navigation & Search
map("n", "<leader>e", "<cmd>Neotree toggle<CR>", silent)
map("n", "<leader>sf", "<cmd>Telescope find_files<CR>", silent)
map("n", "<leader>sg", "<cmd>Telescope live_grep<CR>", silent)
map("n", "<leader>sb", "<cmd>Telescope buffers<CR>", silent)
map("n", "<leader>sh", "<cmd>Telescope help_tags<CR>", silent)
map("n", "<leader>sr", "<cmd>Telescope resume<CR>", silent)

-- Diagnostics & LSP
map("n", "<leader>dd", vim.diagnostic.open_float, silent)
map("n", "<leader>dn", vim.diagnostic.goto_next, silent)
map("n", "<leader>dp", vim.diagnostic.goto_prev, silent)
map("n", "<leader>ca", vim.lsp.buf.code_action, silent)
map("n", "<leader>rn", vim.lsp.buf.rename, silent)
map("n", "gd", vim.lsp.buf.definition, silent)
map("n", "gr", vim.lsp.buf.references, silent)
map("n", "K", vim.lsp.buf.hover, silent)
map("n", "<leader>f", function() require("conform").format({ async = true, lsp_fallback = true }) end, silent)

-- Terminal & Snacks
map("n", "<leader>tt", function() require("snacks").terminal() end, silent)
map("t", "<Esc>", [[<C-\><C-n>]], silent)

-- Academic & Notes
map("n", "<leader>zn", "<cmd>ZkNew<CR>", silent)
map("n", "<leader>zo", "<cmd>ZkNotes<CR>", silent)
map("n", "<leader>zt", "<cmd>ZkTags<CR>", silent)
map("n", "<leader>vc", "<cmd>VimtexCompile<CR>", silent)
map("n", "<leader>vv", "<cmd>VimtexView<CR>", silent)
map("n", "<leader>tn", function() require("venn").toggle() end, silent)
