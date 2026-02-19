-- Diffview.nvim: Advanced git diff viewer with 3-way merge support
return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Git diff (diffview)" },
      { "<leader>gh", "<cmd>DiffviewFileHistory<cr>", desc = "Git file history" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close diffview" },
    },
    config = function()
      require("diffview").setup({
        diff_binaries = false,
        enhanced_diff_hl = false,
        git_cmd = { "git" },
        use_icons = true,
        icons = {
          folder_closed = "",
          folder_open = "",
        },
        signs = {
          fold_closed = "",
          fold_open = "",
          done = "✓",
        },
        view = {
          default = {
            layout = "diff2_horizontal",
          },
          merge_tool = {
            layout = "diff3_horizontal",
            disable_diagnostics = true,
          },
          file_history = {
            layout = "diff2_horizontal",
          },
        },
        file_panel = {
          listing_style = "tree",
          tree_options = {
            flatten_dirs = true,
            folder_statuses = "only_folded",
          },
          win_config = {
            position = "left",
            width = 35,
          },
        },
        file_history_panel = {
          win_config = {
            position = "bottom",
            height = 16,
          },
        },
        commit_log_panel = {
          win_config = {},
        },
        default_args = {
          DiffviewOpen = {},
          DiffviewFileHistory = {},
        },
        hooks = {},
        keymaps = {
          disable_defaults = false,
          view = {
            ["<tab>"] = function() require("diffview.actions").select_next_entry() end,
            ["<s-tab>"] = function() require("diffview.actions").select_prev_entry() end,
            ["gf"] = function() require("diffview.actions").goto_file() end,
            ["<C-w><C-f>"] = function() require("diffview.actions").goto_file_split() end,
            ["<C-w>gf"] = function() require("diffview.actions").goto_file_tab() end,
            ["<leader>e"] = function() require("diffview.actions").focus_files() end,
            ["<leader>b"] = function() require("diffview.actions").toggle_files() end,
            ["g<C-x>"] = function() require("diffview.actions").cycle_layout() end,
            ["[x"] = function() require("diffview.actions").prev_conflict() end,
            ["]x"] = function() require("diffview.actions").next_conflict() end,
          },
          file_panel = {
            ["j"] = function() require("diffview.actions").next_entry() end,
            ["k"] = function() require("diffview.actions").prev_entry() end,
            ["o"] = function() require("diffview.actions").select_entry() end,
            ["s"] = function() require("diffview.actions").toggle_stage_entry() end,
            ["S"] = function() require("diffview.actions").stage_all() end,
            ["U"] = function() require("diffview.actions").unstage_all() end,
            ["X"] = function() require("diffview.actions").restore_entry() end,
            ["R"] = function() require("diffview.actions").refresh_files() end,
            ["<tab>"] = function() require("diffview.actions").select_next_entry() end,
            ["<s-tab>"] = function() require("diffview.actions").select_prev_entry() end,
            ["gf"] = function() require("diffview.actions").goto_file() end,
            ["<C-w><C-f>"] = function() require("diffview.actions").goto_file_split() end,
            ["<C-w>gf"] = function() require("diffview.actions").goto_file_tab() end,
            ["i"] = function() require("diffview.actions").listing_style() end,
            ["f"] = function() require("diffview.actions").toggle_flatten_dirs() end,
            ["g<C-x>"] = function() require("diffview.actions").cycle_layout() end,
            ["[x"] = function() require("diffview.actions").prev_conflict() end,
            ["]x"] = function() require("diffview.actions").next_conflict() end,
          },
          file_history_panel = {
            ["g!"] = function() require("diffview.actions").options() end,
            ["<C-A-d>"] = function() require("diffview.actions").open_in_diffview() end,
            ["y"] = function() require("diffview.actions").copy_hash() end,
            ["L"] = function() require("diffview.actions").open_commit_log() end,
            ["zR"] = function() require("diffview.actions").open_all_folds() end,
            ["zM"] = function() require("diffview.actions").close_all_folds() end,
            ["j"] = function() require("diffview.actions").next_entry() end,
            ["k"] = function() require("diffview.actions").prev_entry() end,
            ["o"] = function() require("diffview.actions").select_entry() end,
            ["<tab>"] = function() require("diffview.actions").select_next_entry() end,
            ["<s-tab>"] = function() require("diffview.actions").select_prev_entry() end,
            ["gf"] = function() require("diffview.actions").goto_file() end,
            ["<C-w><C-f>"] = function() require("diffview.actions").goto_file_split() end,
            ["<C-w>gf"] = function() require("diffview.actions").goto_file_tab() end,
            ["<leader>e"] = function() require("diffview.actions").focus_files() end,
            ["<leader>b"] = function() require("diffview.actions").toggle_files() end,
            ["g<C-x>"] = function() require("diffview.actions").cycle_layout() end,
          },
          option_panel = {
            ["<tab>"] = function() require("diffview.actions").select_entry() end,
            ["q"] = function() require("diffview.actions").close() end,
          },
        },
      })
    end,
  },
}
