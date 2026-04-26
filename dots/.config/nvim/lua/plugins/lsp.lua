-- ~/.config/nvim/lua/plugins/lsp.lua
return {
  { "williamboman/mason.nvim", config = function() require("mason").setup() end },
  { "williamboman/mason-lspconfig.nvim", dependencies = "mason.nvim", config = function()
    require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pylsp", "tsserver", "rust_analyzer", "gopls", "clangd", "html", "cssls", "jsonls", "eslint", "marksman", "bashls", "ltex" } })
  end },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local on_attach = function(_, bufnr)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = bufnr })
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { buffer = bufnr })
      end

      -- Modern LSP config API (0.10+)
      vim.lsp.config.lua_ls = { capabilities = capabilities, on_attach = on_attach, settings = { Lua = { diagnostics = { globals = { "vim" } }, workspace = { library = vim.api.nvim_get_runtime_file("", true) } } } }
      vim.lsp.config.tsserver = { capabilities = capabilities, on_attach = on_attach }
      vim.lsp.config.pylsp = { capabilities = capabilities, on_attach = on_attach }
      vim.lsp.config.rust_analyzer = { capabilities = capabilities, on_attach = on_attach }
      vim.lsp.config.gopls = { capabilities = capabilities, on_attach = on_attach }
      vim.lsp.config.clangd = { capabilities = capabilities, on_attach = on_attach }
      vim.lsp.config.marksman = { capabilities = capabilities, on_attach = on_attach }
      vim.lsp.config.bashls = { capabilities = capabilities, on_attach = on_attach }
      vim.lsp.config.ltex = { capabilities = capabilities, on_attach = on_attach, settings = { ltex = { language = "en-US" } } }
    end,
  },

  -- Formatting & Linting
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua = { "stylua" }, python = { "black", "isort" }, javascript = { "prettier" }, typescript = { "prettier" },
          markdown = { "prettier" }, json = { "prettier" }, yaml = { "prettier" }, rust = { "rustfmt" },
          go = { "gofmt" }, cpp = { "clang_format" }, c = { "clang_format" }, html = { "prettier" },
          css = { "prettier" }, bash = { "shfmt" },
        },
        format_on_save = { timeout_ms = 500, lsp_fallback = true },
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost" },
    config = function()
      require("lint").linters_by_ft = {
        python = { "pylint", "mypy" }, javascript = { "eslint" }, typescript = { "eslint" },
        markdown = { "markdownlint" }, latex = { "chktex" }, cpp = { "cppcheck" }, go = { "staticcheck" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, { callback = function() require("lint").try_lint() end })
    end,
  },

  { "ray-x/lsp_signature.nvim", event = "BufReadPost", config = function() require("lsp_signature").setup({ hint_prefix = "⚙️ " }) end },
}
