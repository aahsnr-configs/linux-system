vim.g.autoformat = true

local augroup = vim.api.nvim_create_augroup("CoreAutocmds", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
	group = augroup,
	callback = function()
		vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
	end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
	group = augroup,
	callback = function()
		vim.cmd([[%s/\s\+$//e]])
	end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup,
	callback = function(ev)
		if vim.bo[ev.buf].filetype == "gitcommit" then
			return
		end
		local last = vim.fn.line("'\"")
		if last > 1 and last <= vim.fn.line("$") then
			vim.cmd('normal! g`"')
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "*",
	callback = function()
		vim.opt_local.formatoptions:remove({ "c", "r", "o" })
	end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
	group = augroup,
	callback = function(ev)
		if not vim.g.autoformat then
			return
		end
		local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
		local clients = get_clients({ bufnr = ev.buf })
		local can_format = false
		for _, client in ipairs(clients) do
			if client.supports_method and client.supports_method("textDocument/formatting") then
				can_format = true
				break
			end
		end
		if can_format then
			vim.lsp.buf.format({ async = false, timeout_ms = 1000 })
		end
	end,
})

vim.keymap.set("n", "<leader>tf", function()
	vim.g.autoformat = not vim.g.autoformat
	local state = vim.g.autoformat and "enabled" or "disabled"
	vim.notify("Autoformat " .. state)
end, { desc = "Toggle format-on-save" })
