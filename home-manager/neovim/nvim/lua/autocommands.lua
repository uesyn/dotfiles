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

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("my_oil", { clear = true }),
    pattern = "oil",
    callback = function()
        vim.bo.buflisted = false
        vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<Leader>fe", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<Leader>fo", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<Leader>ff", "<Nop>", { buffer = true })
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("my_neo_tree", { clear = true }),
    pattern = "neo-tree",
    callback = function()
        vim.bo.buflisted = false
        vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<Leader>fe", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<Leader>ff", "<Nop>", { buffer = true })
    end,
})
