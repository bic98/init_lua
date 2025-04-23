local lspconfig = require('lspconfig')

-- Add path to Python libraries
local util = require('lspconfig.util')
local path = util.path

-- Configure Python LSP
lspconfig.pyright.setup({
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "workspace",
        useLibraryCodeForTypes = true,
        extraPaths = {
          -- Add TensorFlow paths
          path.join(vim.fn.expand('$HOME'), '.local/lib/python3.12/site-packages'),
          path.join(vim.fn.expand('$HOME'), 'miniconda3/lib/python3.12/site-packages')
        }
      }
    }
  }
})