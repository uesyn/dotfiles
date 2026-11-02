-- `gopls` build tags come from the environment so that per-project tags can be
-- set without editing this file.
local build_flags = {}
if vim.env.GOPLS_BUILD_TAGS then
  table.insert(build_flags, "-tags")
  table.insert(build_flags, vim.env.GOPLS_BUILD_TAGS)
end

return {
  cmd = { "gopls" },
  root_markers = { "go.work", "go.mod", ".git" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  settings = {
    gopls = {
      buildFlags = build_flags,
      -- Inlay hints: off, the code is readable without them.
      hints = {
        assignVariableTypes = false,
        compositeLiteralFields = false,
        compositeLiteralTypes = false,
        constantValues = false,
        functionTypeParameters = false,
        parameterNames = false,
        rangeVariableTypes = false,
      },
    },
  },
}
