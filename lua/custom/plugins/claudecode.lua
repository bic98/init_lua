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
    lazy = false,
    opts = {
      -- Server Configuration
      port_range = { min = 10000, max = 65535 },
      auto_start = true,
      log_level = 'info',

      -- Connection Management (from PR #43)
      connection_wait_delay = 200,
      connection_timeout = 10000,
      queue_timeout = 5000,

      -- Selection Tracking
      track_selection = true,
      visual_demotion_delay_ms = 50,

      -- Terminal Configuration
      terminal = {
        split_side = 'right',
        split_width_percentage = 0.35,
        provider = 'snacks',
        auto_close = false,
      },

      -- Diff Integration
      diff_opts = {
        auto_close_on_accept = true,
        vertical_split = true,
        open_in_current_tab = true,
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
      -- Visual mode keymaps - Use : instead of <cmd> to pass range
      -- ============================================================
      { '<leader>as', ':ClaudeCodeSend<cr>', mode = 'v', desc = 'Send to Claude' },
      { '<leader>av', ':ClaudeCodeSend<cr>', mode = 'v', desc = 'Send to Claude' },
      { '<leader>ae', ':ClaudeCodeSend<cr>', mode = 'v', desc = 'Explain code' },
      { '<leader>at', ':ClaudeCodeSend<cr>', mode = 'v', desc = 'Generate tests' },
      { '<leader>aR', ':ClaudeCodeSend<cr>', mode = 'v', desc = 'Review code' },
      { '<leader>aF', ':ClaudeCodeSend<cr>', mode = 'v', desc = 'Refactor code' },
      { '<leader>an', ':ClaudeCodeSend<cr>', mode = 'v', desc = 'Better naming' },
      { '<leader>ax', ':ClaudeCodeSend<cr>', mode = 'v', desc = 'Fix error' },

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
