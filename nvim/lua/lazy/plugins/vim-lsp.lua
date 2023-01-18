return {
  'prabirshrestha/vim-lsp',
  dependencies = {
    'prabirshrestha/asyncomplete.vim',
    'prabirshrestha/asyncomplete-lsp.vim',
    'mattn/vim-lsp-settings',
  },
  init = function()
    vim.g.lsp_work_done_progress_enabled = 1
    vim.g.lsp_document_code_action_signs_enabled = 0
    vim.g.lsp_diagnostics_echo_cursor = 1
    vim.g.lsp_diagnostics_echo_delay = 50
    vim.g.lsp_diagnostics_highlights_enabled = 0
    vim.g.lsp_diagnostics_highlights_delay = 50
    vim.g.lsp_diagnostics_highlights_insert_mode_enabled = 0
    vim.g.lsp_diagnostics_signs_enabled = 1
    vim.g.lsp_diagnostics_signs_delay = 50
    vim.g.lsp_diagnostics_signs_insert_mode_enabled = 0
    vim.g.lsp_diagnostics_virtual_text_enabled = 0
    vim.g.lsp_diagnostics_virtual_text_delay = 50
    vim.g.lsp_diagnostics_float_cursor = 0
    vim.g.lsp_diagnostics_float_delay = 1000
    vim.g.lsp_completion_documentation_delay = 40
    vim.g.lsp_document_highlight_delay = 50
    vim.g.lsp_document_code_action_signs_delay = 100
    vim.g.lsp_fold_enabled = 0
    vim.g.lsp_text_edit_enabled = 0
    vim.g.lsp_settings_filetype_typescript = {'typescript-language-server', 'deno'}
    vim.g.lsp_settings_filetype_javascript = {'typescript-language-server', 'deno'}
  end,
  config = function()
    vim.keymap.set('n', '[LSP]D', "<plug>(lsp-declaration)")
    vim.keymap.set('n', '[LSP]d', "<plug>(lsp-definition)")
    vim.keymap.set('n', '[LSP]h', "<plug>(lsp-hover)")
    vim.keymap.set('n', '[LSP]t', "<plug>(lsp-type-definition)")
    vim.keymap.set('n', '[LSP]r', "<plug>(lsp-references)")
    vim.keymap.set('n', '[LSP]R', "<plug>(lsp-rename)")
    vim.keymap.set('n', '[LSP]a', "<plug>(lsp-code-action)")
    vim.keymap.set('n', '[LSP]f', "<plug>(lsp-document-format)")
    vim.keymap.set('n', '[LSP]q', "<plug>(lsp-document-diagnostics)")
    vim.keymap.set('n', '[LSP]i', "<Cmd>LspCodeActionSync source.organizeImports<CR>")
    vim.opt.signcolumn = "yes"
    vim.opt.omnifunc = "lsp#complete"
  end,
}
