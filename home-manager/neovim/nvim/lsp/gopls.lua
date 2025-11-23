local build_flags = {}
if vim.env.GOPLS_BUILD_TAGS then
  table.insert(build_flags, '-tags')
  table.insert(build_flags, vim.env.GOPLS_BUILD_TAGS)
end

return {
  cmd = { 'gopls' },
  root_markers = { 'go.work', 'go.mod', '.git' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  settings = {
    gopls = {
      hints = {
        assignVariableTypes = false,
        compositeLiteralFields = false,
        compositeLiteralTypes = false,
        constantValues = false,
        functionTypeParameters = false,
        parameterNames = false,
        rangeVariableTypes = false,
      },
      buildFlags = build_flags,
    },
  },
}
