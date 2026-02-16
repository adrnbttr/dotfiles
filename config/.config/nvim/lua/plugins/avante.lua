return {
  {
    "yetone/avante.nvim",
    build = vim.fn.has("win32") ~= 0
      and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",
    event = "VeryLazy",
    version = false,

    ---@module 'avante'
    ---@type avante.Config
    opts = {
      instructions_file = "avante.md",

      -- Utilise OpenRouter avec Claude 3.5 Sonnet
      provider = "openrouter",
      providers = {
        openrouter = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          model = "anthropic/claude-3.5-sonnet",
          api_key_name = "OPENROUTER_API_KEY",
          extra_request_body = {
            temperature = 0.6,
          },
        },
      },

      -- Raccourcis adaptés pour un clavier bépo
      mappings = {
        ask = "<leader>aa",
        new_ask = "<leader>an",
        zen_mode = "<leader>az",
        edit = "<leader>ae",
        refresh = "<leader>ar",
        focus = "<leader>af",
        stop = "<leader>aS",

        toggle = {
          default = "<leader>at",
          suggestion = "<leader>as",
          debug = "<leader>ad",
          selection = "<leader>aC",
          repomap = "<leader>aR",
        },

        -- Suggestions inline (touches dédiées, distinctes de Codeium)
        suggestion = {
          accept = "<M-l>",
          next = "<M-j>",
          prev = "<M-k>",
          dismiss = "<M-h>",
        },

        -- Navigation prompts sans [ / ]
        sidebar = {
          next_prompt = "<leader>aj",
          prev_prompt = "<leader>ak",
          apply_all = "A",
          apply_cursor = "a",
          retry_user_request = "r",
          edit_user_request = "e",
          switch_windows = "<Tab>",
          reverse_switch_windows = "<S-Tab>",
          toggle_code_window = "x",
          remove_file = "d",
          add_file = "@",
          close = { "q" },
          close_from_input = nil,
          toggle_code_window_from_input = nil,
        },

        -- Sauts dans l'historique / éléments (évite ]] / [[)
        jump = {
          next = "<leader>jn",
          prev = "<leader>jp",
        },

        -- Diff : on garde les mappings Vim classiques
        diff = {
          ours = "co",
          theirs = "ct",
          all_theirs = "ca",
          both = "cb",
          cursor = "cc",
          next = "]x",
          prev = "[x",
        },

        files = {
          add_current = "<leader>ac",
          add_all_buffers = "<leader>aB",
        },

        confirm = {
          focus_window = "<C-w>f",
          code = "c",
          resp = "r",
          input = "i",
          },
      },

      -- Comportement plus minimaliste : moins de blocs redondants,
      -- appliquer directement les diffs et sauter au résultat.
      behaviour = {
        auto_apply_diff_after_generation = true,
        minimize_diff = true,
        jump_result_buffer_on_finish = true,
      },

      -- Layout plus discret : sidebar compacte, sans gros header,
      -- et pas de wrap dans la zone Avante.
      windows = {
        position = "right",
        width = 25,
        wrap = false,
        sidebar_header = {
          enabled = false,
          rounded = false,
        },
        input = {
          height = 5,
        },
      },

      -- Utilise snacks.nvim (déjà présent via opencode)
      input = {
        provider = "snacks",
        provider_opts = {
          title = "Avante Input",
          icon = " ",
        },
      },
    },

    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "Avante" },
        opts = {
          file_types = { "markdown", "Avante" },
        },
      },
      "folke/snacks.nvim",
    },
  },
}
