-- ============================================================
-- MARKDOWN SUITE
-- render-markdown.nvim · marksman LSP · nvim-lint · conform
-- File: ~/.config/nvim/lua/custom/plugins/markdown.lua
-- ============================================================

local function gh(repo) return 'https://github.com/' .. repo end

-- ── render-markdown.nvim ──────────────────────────────────────────────────
-- NOTE: nvim-treesitter and mini.nvim are already added by init.lua,
--       so we only need to add render-markdown itself here.
vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {
  -- Active vim modes that show the rendered view (:h mode())
  -- Other modes (insert, visual, …) always show raw markdown.
  render_modes = { 'n', 'c', 't' },

  -- Momentarily reveal the raw syntax under the cursor
  anti_conceal = {
    enabled = true,
    above = 0,
    below = 0,
  },

  -- ── Headings ─────────────────────────────────────────────────────────
  heading = {
    enabled = true,
    sign = false, -- keep signcolumn clean
    position = 'overlay', -- icon overlays the '#' characters
    icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
    width = 'full', -- background spans the full window width
    min_width = 0,
    left_pad = 0,
    right_pad = 0,
    backgrounds = {
      'RenderMarkdownH1Bg',
      'RenderMarkdownH2Bg',
      'RenderMarkdownH3Bg',
      'RenderMarkdownH4Bg',
      'RenderMarkdownH5Bg',
      'RenderMarkdownH6Bg',
    },
    foregrounds = {
      'RenderMarkdownH1',
      'RenderMarkdownH2',
      'RenderMarkdownH3',
      'RenderMarkdownH4',
      'RenderMarkdownH5',
      'RenderMarkdownH6',
    },
  },

  -- ── Code blocks ──────────────────────────────────────────────────────
  code = {
    enabled = true,
    sign = false, -- no signcolumn mark
    style = 'full', -- render language label + border
    position = 'left',
    language_pad = 1,
    language_name = true,
    language_icon = true,
    disable_background = { 'diff' },
    width = 'block', -- tight block (not full window width)
    left_pad = 2,
    right_pad = 2,
    min_width = 50,
    border = 'thin', -- 'thin' | 'thick' | 'hide' | 'none'
    highlight = 'RenderMarkdownCode',
    highlight_language = 'RenderMarkdownCodeLanguage',
    highlight_border = 'RenderMarkdownCodeBorder',
    inline_highlight = 'RenderMarkdownCodeInline',
  },

  -- ── Horizontal rules ─────────────────────────────────────────────────
  dash = {
    enabled = true,
    icon = '─',
    width = 'full',
    highlight = 'RenderMarkdownDash',
  },

  -- ── Bullet lists ─────────────────────────────────────────────────────
  bullet = {
    enabled = true,
    icons = { '●', '○', '◆', '◇' }, -- cycled per nesting level
    right_pad = 1,
    highlight = 'RenderMarkdownBullet',
  },

  -- ── Checkboxes ───────────────────────────────────────────────────────
  checkbox = {
    enabled = true,
    position = 'inline',
    unchecked = { icon = '󰄱 ', highlight = 'RenderMarkdownUnchecked' },
    checked = { icon = '󰱒 ', highlight = 'RenderMarkdownChecked' },
    custom = {
      todo = { raw = '[-]', rendered = '󰥔 ', highlight = 'RenderMarkdownTodo' },
    },
  },

  -- ── Block-quotes ─────────────────────────────────────────────────────
  quote = {
    enabled = true,
    icon = '▋',
    repeat_linebreak = false,
    highlight = 'RenderMarkdownQuote',
  },

  -- ── GitHub-style callouts / alerts ───────────────────────────────────
  callout = {
    note = { raw = '[!NOTE]', rendered = '󰋽 Note', highlight = 'RenderMarkdownInfo' },
    tip = { raw = '[!TIP]', rendered = '󰌶 Tip', highlight = 'RenderMarkdownSuccess' },
    important = { raw = '[!IMPORTANT]', rendered = '󰅾 Important', highlight = 'RenderMarkdownHint' },
    warning = { raw = '[!WARNING]', rendered = '󰀪 Warning', highlight = 'RenderMarkdownWarn' },
    caution = { raw = '[!CAUTION]', rendered = '󰳦 Caution', highlight = 'RenderMarkdownError' },
    abstract = { raw = '[!ABSTRACT]', rendered = '󰨸 Abstract', highlight = 'RenderMarkdownInfo' },
    info = { raw = '[!INFO]', rendered = '󰋽 Info', highlight = 'RenderMarkdownInfo' },
    todo = { raw = '[!TODO]', rendered = '󰗡 Todo', highlight = 'RenderMarkdownInfo' },
    success = { raw = '[!SUCCESS]', rendered = '󰄬 Success', highlight = 'RenderMarkdownSuccess' },
    question = { raw = '[!QUESTION]', rendered = '󰘥 Question', highlight = 'RenderMarkdownWarn' },
    failure = { raw = '[!FAILURE]', rendered = '󰅖 Failure', highlight = 'RenderMarkdownError' },
    danger = { raw = '[!DANGER]', rendered = '󱐌 Danger', highlight = 'RenderMarkdownError' },
    bug = { raw = '[!BUG]', rendered = '󰨰 Bug', highlight = 'RenderMarkdownError' },
    example = { raw = '[!EXAMPLE]', rendered = '󰉹 Example', highlight = 'RenderMarkdownHint' },
    quote = { raw = '[!QUOTE]', rendered = '󱆨 Quote', highlight = 'RenderMarkdownQuote' },
  },

  -- ── Links ────────────────────────────────────────────────────────────
  link = {
    enabled = true,
    footnote = { superscript = true, prefix = '', suffix = '' },
    image = '󰥶 ',
    email = '󰀓 ',
    hyperlink = '󰌹 ',
    highlight = 'RenderMarkdownLink',
    wiki = { icon = '󱗖 ', highlight = 'RenderMarkdownWikiLink' },
    custom = {
      web = { pattern = '^http', icon = '󰖟 ', highlight = 'RenderMarkdownLink' },
    },
  },

  -- ── Tables ───────────────────────────────────────────────────────────
  pipe_table = {
    enabled = true,
    preset = 'double', -- 'none' | 'single' | 'double' | 'heavy'
    alignment_indicator = '━',
    head = 'RenderMarkdownTableHead',
    row = 'RenderMarkdownTableRow',
    filler = 'RenderMarkdownTableFill',
  },

  -- ── blink.cmp completions (checkboxes + callouts via LSP source) ─────
  completions = {
    lsp = { enabled = true },
  },

  -- ── Signcolumn / indent ───────────────────────────────────────────────
  sign = { enabled = false },
  indent = { enabled = false },
}

-- ── Markdown buffer options ───────────────────────────────────────────────
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  group = vim.api.nvim_create_augroup('markdown-options', { clear = true }),
  callback = function(args)
    local buf = args.buf

    -- Visual soft-wrap (no hard line-break characters are inserted)
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.breakindent = true

    -- Conceallevel expected by render-markdown
    vim.wo.conceallevel = 2

    -- Spell checking
    vim.opt_local.spell = true
    vim.opt_local.spelllang = 'en_us'

    -- Navigate by display line when wrapping is on
    local opts = { buffer = buf, silent = true }
    vim.keymap.set('n', 'j', 'gj', vim.tbl_extend('force', opts, { desc = 'Markdown: down display-line' }))
    vim.keymap.set('n', 'k', 'gk', vim.tbl_extend('force', opts, { desc = 'Markdown: up display-line' }))
    vim.keymap.set('n', '$', 'g$', vim.tbl_extend('force', opts, { desc = 'Markdown: end display-line' }))
    vim.keymap.set('n', '^', 'g^', vim.tbl_extend('force', opts, { desc = 'Markdown: first non-blank' }))
    vim.keymap.set('n', '0', 'g0', vim.tbl_extend('force', opts, { desc = 'Markdown: start display-line' }))
  end,
})

-- ── Keymaps ───────────────────────────────────────────────────────────────
vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', { desc = '[T]oggle [M]arkdown render' })
