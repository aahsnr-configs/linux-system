-- ~/.config/nvim/lua/config/options.lua
local opt = vim.opt

-- Core
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.laststatus = 3
opt.cmdheight = 0
opt.termguicolors = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.autowrite = true
opt.hidden = true

-- File & Performance
opt.swapfile = false
opt.backup = false
opt.undodir = vim.fn.stdpath("state") .. "/undodir"
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 300

-- Editing
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true
opt.backspace = "indent,eol,start"
opt.whichwrap = "b,s,<,>,[,],h,l"
opt.formatoptions:remove("c", "r", "o")

-- Search & Completion
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.completeopt = "menu,menuone,noselect,popup"
opt.pumheight = 12
opt.shortmess:append("c")

-- UI & Layout
opt.colorcolumn = "88"
opt.wrap = true
opt.linebreak = true
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Academic Defaults
opt.spelllang = { "en_us" }
opt.spelloptions = "camel"
