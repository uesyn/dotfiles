-- Global keymaps. Plugin keymaps live next to their plugin in lua/plugins.

-- <leader> is only a prefix. The exits below are disabled on purpose: quitting
-- and macro recording are too easy to trigger by accident.
vim.keymap.set({ "n", "v" }, "<leader>", "<Nop>", { desc = "Leader prefix" })
vim.keymap.set("n", "ZZ", "<Nop>", { desc = "Disabled: save and quit" })
vim.keymap.set("n", "ZQ", "<Nop>", { desc = "Disabled: quit without saving" })
vim.keymap.set("n", "q", "<Nop>", { desc = "Disabled: macro recording" })
vim.keymap.set("n", "Q", "<Nop>", { desc = "Disabled: Ex mode" })

-- Accept the selected completion item instead of closing the popup first.
vim.keymap.set("i", "<CR>", function()
  if vim.fn.pumvisible() == 1 then
    return "<C-e><CR>"
  end
  return "<CR>"
end, { expr = true, desc = "Accept completion or insert newline" })
