-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'iamcco/markdown-preview.nvim',
    lazy = false,
    build = 'cd app && yarn install',
    config = function()
      vim.g.mkdp_filetypes = { 'markdown' }
    end,
  },
}
