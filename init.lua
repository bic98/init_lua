-- Compatibility entry point for an older Windows checkout located at stdpath('config').
-- Fresh installs copy window/settings/nvim and do not use this repository-root shim.
local platform_config = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h') .. '/window/settings/nvim'
vim.opt.runtimepath:prepend(platform_config)
dofile(platform_config .. '/init.lua')
