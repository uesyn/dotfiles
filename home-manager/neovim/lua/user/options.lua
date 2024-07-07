vim.loader.enable()

-- Set up globals {{{
vim.g["loaded_perl_provider"] = 0
vim.g["loaded_python_provider"] = 0
vim.g["loaded_ruby_provider"] = 0
vim.g["mapleader"] = " "
vim.g["netrw_fastbrowse"] = 0
vim.g["vim_markdown_conceal"] = 0
vim.g["vim_markdown_no_default_key_mappings"] = 1
-- }}}

-- Set up options {{{
vim.opt["ambiwidth"] = "single"
vim.opt["breakindent"] = true
vim.opt["emoji"] = true
vim.opt["fileformats"] = { "unix", "dos", "mac" }
vim.opt["foldcolumn"] = "0"
vim.opt["inccommand"] = "split"
vim.opt["laststatus"] = 3
vim.opt["maxmempattern"] = 20000
vim.opt["number"] = true
vim.opt["relativenumber"] = true
vim.opt["showcmd"] = false
vim.opt["showmode"] = false
vim.opt["showtabline"] = 2
vim.opt["signcolumn"] = "yes"
vim.opt["synmaxcol"] = 320
vim.opt["updatetime"] = 100
vim.opt["wildmode"] = "full"

-- Ignore the user lua configuration
vim.opt.runtimepath:remove(vim.fn.stdpath("config")) -- ~/.config/nvim
vim.opt.runtimepath:remove(vim.fn.stdpath("config") .. "/after") -- ~/.config/nvim/after
vim.opt.runtimepath:remove(vim.fn.stdpath("data") .. "/site") -- ~/.local/share/nvim/site
-- }}}

-- keymaps {{{
vim.keymap.set("n", "<C-h>", "<C-w><")
vim.keymap.set("n", "<C-j>", "<C-w>-")
vim.keymap.set("n", "<C-k>", "<C-w>+")
vim.keymap.set("n", "<C-l>", "<C-w>>")
vim.keymap.set({"n", "v"}, "<leader>", "<Nop>")
vim.keymap.set("n", "ZZ", "<Nop>")
vim.keymap.set("n", "ZQ", "<Nop>")
vim.keymap.set("n", "q", "<Nop>")
vim.keymap.set("n", "Q", "<Nop>")
vim.keymap.set("n", "<S-l>", "<C-w>l")
vim.keymap.set("n", "<S-h>", "<C-w>h")
vim.keymap.set("n", "<S-k>", "<C-w>k")
vim.keymap.set("n", "<S-j>", "<C-w>j")
-- }}}

-- autocmds {{{
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("my_quickfix", { clear = true }),
    pattern = "qf",
    callback = function()
        vim.bo.buflisted = false
        vim.keymap.set("n", "<C-q>", "<Cmd>clo<CR>", { buffer = true })
        vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
    end,
})
-- }}}
