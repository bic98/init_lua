-- Claude Code integration for Neovim
-- https://github.com/coder/claudecode.nvim
-- Replaces GitHub Copilot Chat with Claude Code

-- Helper function to send selection with a prompt
local function send_with_prompt(prompt)
  return function()
    -- First send the selection
    vim.cmd('ClaudeCodeSend')
    -- Then we can type in the terminal - Claude Code will see the selection
    vim.notify('Selection sent to Claude. Type your request in the terminal.', vim.log.levels.INFO)
  end
end

-- Helper function to open Claude and send a message
local function claude_ask(prompt)
  return function()
    -- Open Claude if not open
    vim.cmd('ClaudeCode')
    -- Notify user to type
    vim.notify('Claude opened. Ask: ' .. prompt, vim.log.levels.INFO)
  end
end

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
    opts = {
      -- Server Configuration
      port_range = { min = 10000, max = 65535 },
      auto_start = true,
      log_level = 'info', -- "trace", "debug", "info", "warn", "error"
      terminal_cmd = nil, -- Custom terminal command (default: "claude")

      -- Send/Focus Behavior
      focus_after_send = true, -- Focus terminal after sending selection

      -- Selection Tracking
      track_selection = true,
      visual_demotion_delay_ms = 50,

      -- Terminal Configuration
      terminal = {
        split_side = 'right', -- "left" or "right"
        split_width_percentage = 0.35, -- 35% width
        provider = 'snacks', -- "auto", "snacks", "native", "external", "none"
        auto_close = true,
        git_repo_cwd = true, -- Use git root as working directory
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
      -- AI/Claude Code Group (replacing Copilot Chat keymaps)
      -- ============================================================
      { '<leader>a', nil, desc = 'AI/Claude Code' },

      -- Basic Controls
      { '<leader>ac', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude' },
      { '<leader>af', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
      { '<leader>ar', '<cmd>ClaudeCode --resume<cr>', desc = 'Resume Claude' },
      { '<leader>aC', '<cmd>ClaudeCode --continue<cr>', desc = 'Continue Claude' },

      -- Context Management
      { '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', desc = 'Add current buffer' },
      { '<leader>as', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send to Claude' },

      -- File tree integration
      {
        '<leader>as',
        '<cmd>ClaudeCodeTreeAdd<cr>',
        desc = 'Add file to Claude',
        ft = { 'NvimTree', 'neo-tree', 'oil', 'minifiles', 'netrw' },
      },

      -- Diff management
      { '<leader>aA', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Accept diff' },
      { '<leader>aD', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Deny diff' },

      -- ============================================================
      -- Copilot-style keymaps (selection + prompt workflow)
      -- These send selection then you type in Claude terminal
      -- ============================================================

      -- Code explanation (was <leader>ae in Copilot)
      {
        '<leader>ae',
        function()
          vim.cmd('ClaudeCodeSend')
          vim.schedule(function()
            vim.cmd('ClaudeCodeFocus')
          end)
        end,
        mode = 'v',
        desc = 'Explain code',
      },

      -- Generate tests (was <leader>at in Copilot)
      {
        '<leader>at',
        function()
          vim.cmd('ClaudeCodeSend')
          vim.schedule(function()
            vim.cmd('ClaudeCodeFocus')
          end)
        end,
        mode = 'v',
        desc = 'Generate tests',
      },

      -- Review code (was <leader>ar in Copilot - now <leader>aR to avoid conflict)
      {
        '<leader>aR',
        function()
          vim.cmd('ClaudeCodeSend')
          vim.schedule(function()
            vim.cmd('ClaudeCodeFocus')
          end)
        end,
        mode = 'v',
        desc = 'Review code',
      },

      -- Refactor code
      {
        '<leader>aF',
        function()
          vim.cmd('ClaudeCodeSend')
          vim.schedule(function()
            vim.cmd('ClaudeCodeFocus')
          end)
        end,
        mode = 'v',
        desc = 'Refactor code',
      },

      -- Better naming
      {
        '<leader>an',
        function()
          vim.cmd('ClaudeCodeSend')
          vim.schedule(function()
            vim.cmd('ClaudeCodeFocus')
          end)
        end,
        mode = 'v',
        desc = 'Better naming',
      },

      -- Fix error/diagnostic
      {
        '<leader>ax',
        function()
          vim.cmd('ClaudeCodeSend')
          vim.schedule(function()
            vim.cmd('ClaudeCodeFocus')
          end)
        end,
        mode = 'v',
        desc = 'Fix error',
      },

      -- Quick chat / Ask input (was <leader>ai, <leader>aq in Copilot)
      {
        '<leader>ai',
        function()
          local input = vim.fn.input('Ask Claude: ')
          if input ~= '' then
            vim.cmd('ClaudeCode')
            vim.notify('Type in Claude terminal: ' .. input, vim.log.levels.INFO)
          end
        end,
        desc = 'Ask Claude',
      },

      -- Model selection (was <leader>a? in Copilot)
      { '<leader>am', '<cmd>ClaudeCodeSelectModel<cr>', desc = 'Select model' },

      -- Clear/Reset - close and reopen
      {
        '<leader>al',
        function()
          vim.cmd('ClaudeCode') -- Close if open
          vim.defer_fn(function()
            vim.cmd('ClaudeCode') -- Reopen fresh
          end, 100)
        end,
        desc = 'Reset Claude',
      },
    },
  },
}
