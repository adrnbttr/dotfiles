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

      -- Comportement plus minimaliste : moins de blocs redondants,
      -- appliquer directement les diffs et sauter au résultat.
      behaviour = {
        auto_apply_diff_after_generation = true,
        minimize_diff = true,
        jump_result_buffer_on_finish = true,
        -- Le hint "Tokens: ...; <key>: submit" prend beaucoup de place visuelle.
        -- On garde l'UI plus clean en le desactivant.
        enable_token_counting = false,
      },

      -- Layout plus agreable : plus large, wrap actif (pas de scroll horizontal),
      -- input plus haut pour eviter l'effet "colle".
      windows = {
        position = "right",
        width = 35,
        wrap = true,
        sidebar_header = {
          enabled = false,
          rounded = false,
        },
        input = {
          height = 10,
          padding = { 1, 1, 1, 1 }, -- padding top, right, bottom, left
          border = {
            style = "rounded",
            padding = { 1, 1 },
          },
        },
        layout = {
          mode = "split",
          preview = {
            position = "top",
            height = 0.4,
          },
          response = {
            position = "bottom",
            height = 0.4,
          },
        },
        preview = {
          enabled = true,
        },
        response = {
          enabled = true,
          show_code = true,
        },
      },

      -- UX: "Enter" pour envoyer dans l'input Avante.
      -- On mappe ensuite Shift-Enter / Ctrl-j pour inserer une nouvelle ligne.
      mappings = {
        submit = {
          normal = "<CR>",
          insert = "<CR>",
        },

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

        -- Suggestions inline (touches dediees, distinctes de Codeium)
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

        -- Sauts dans l'historique / elements (evite ]] / [[)
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
