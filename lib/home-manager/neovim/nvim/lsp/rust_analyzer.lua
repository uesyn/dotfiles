return {
  cmd = { 'rust-analyzer' },
  root_markers = { 'Cargo.toml' },
  filetypes = { 'rust' },
  settings = {
    ["rust-analyzer"] = {
      cargo = { allFeatures = true },
      checkOnSave = { allFeatures = true },
      diagnostics = {
	enable = true,
	disabled = { "unresolved-proc-macro" },
	enableExperimental = true,
      },
    },
  },
}
