-- Copilot language server. Behaviour (sign-in, inline completion) lives in
-- lua/config/copilot.lua; keep this file declarative.
return {
  cmd = { "copilot-language-server", "--stdio" },
  root_markers = { ".git" },
  init_options = {
    editorInfo = {
      name = "Neovim",
      version = tostring(vim.version()),
    },
    editorPluginInfo = {
      name = "Neovim",
      version = tostring(vim.version()),
    },
  },
}
