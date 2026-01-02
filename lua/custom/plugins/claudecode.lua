-- Claude Code integration for Neovim
-- https://github.com/coder/claudecode.nvim
-- Replaces GitHub Copilot Chat with Claude Code

return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {},
  },
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    config = true,
    opts = {
      -- Server Configuration
      port_range = { min = 10000, max = 65535 },
      auto_start = true,
      log_level = 'info',
      terminal_cmd = nil,

      -- Send/Focus Behavior
      focus_after_send = true,

      -- Selection Tracking
      track_selection = true,
      visual_demotion_delay_ms = 50,

      -- Terminal Configuration
      terminal = {
        split_side = 'right',
        split_width_percentage = 0.35,
        provider = 'snacks',
        auto_close = true,
        git_repo_cwd = true,
      },

      -- Diff Integration
      diff_opts = {
        auto_close_on_accept = true,
        vertical_split = true,
        open_in_current_tab = true,
        keep_terminal_focus = false,
      },
    },
    keys = {
      -- ============================================================
      -- AI/Claude Code Group
      -- ============================================================
      { '<leader>a', nil, desc = 'AI/Claude Code' },

      -- Basic Controls (Normal mode)
      { '<leader>ac', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude' },
      { '<leader>af', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
      { '<leader>ar', '<cmd>ClaudeCode --resume<cr>', desc = 'Resume Claude' },
      { '<leader>aC', '<cmd>ClaudeCode --continue<cr>', desc = 'Continue Claude' },
      { '<leader>am', '<cmd>ClaudeCodeSelectModel<cr>', desc = 'Select model' },
      { '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', desc = 'Add current buffer' },

      -- Diff management
      { '<leader>aA', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Accept diff' },
      { '<leader>aD', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Deny diff' },

      -- ============================================================
      -- Visual mode keymaps - ALL use <cmd> to preserve selection
      -- ============================================================
      { '<leader>as', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send to Claude' },
      { '<leader>ae', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Explain code' },
      { '<leader>at', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Generate tests' },
      { '<leader>aR', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Review code' },
      { '<leader>aF', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Refactor code' },
      { '<leader>an', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Better naming' },
      { '<leader>ax', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Fix error' },

      -- File tree integration
      {
        '<leader>as',
        '<cmd>ClaudeCodeTreeAdd<cr>',
        desc = 'Add file to Claude',
        ft = { 'NvimTree', 'neo-tree', 'oil', 'minifiles', 'netrw' },
      },
    },
  },
}
