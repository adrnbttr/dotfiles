return {
  {
    "Exafunction/codeium.nvim",
    cmd = "Codeium",
    event = "InsertEnter",
    build = ":Codeium Auth",
    opts = {
      -- Ghost text (virtual_text) only. Keep the completion menu for LSP/snippets.
      enable_cmp_source = false,
      virtual_text = {
        enabled = true,
        key_bindings = {
          -- Accept is handled by our <C-l> mapping and blink.cmp's <Tab> ai_accept action.
          accept = false,
          next = "<M-Right>",
          prev = "<M-Left>",
          clear = "<M-Down>",
        },
      },
    },
  },
  {
    "Exafunction/codeium.nvim",
    opts = function()
      local lv = rawget(_G, "LazyVim")
      local function codeium_accept()
        local ok, vt = pcall(require, "codeium.virtual_text")
        if ok and vt.get_current_completion_item() then
          if lv and lv.create_undo then
            lv.create_undo()
          end
          vim.api.nvim_input(vt.accept())
          return true
        end
      end

      -- Provide LazyVim's ai_accept action so blink.cmp can accept Codeium suggestions on <Tab>.
      if lv and lv.cmp and lv.cmp.actions then
        lv.cmp.actions.ai_accept = codeium_accept
      end

      -- Keep your existing accept binding (previously Copilot) on <C-l>.
      vim.keymap.set("i", "<C-l>", function()
        codeium_accept()
      end, { desc = "Accept AI suggestion" })
    end,
  },
  -- Make sure Copilot doesn't load (avoid conflicting ghost text).
  { "github/copilot.vim", enabled = false },
  { "zbirenbaum/copilot.lua", enabled = false },
  { "CopilotC-Nvim/CopilotChat.nvim", enabled = false },
  {
    "lukas-reineke/indent-blankline.nvim",
    enabled = false
  },
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
        -- Recommended for `ask()` and `select()`.
        -- Required for `snacks` provider.
        ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
        { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
        ---@type opencode.Opts
        vim.g.opencode_opts = {
        -- Performance optimizations
        events = {
            reload = function()
                vim.schedule(function()
                    vim.cmd("checktime")
                end)
            end,
        },
        -- Memory management
        max_session_messages = 200,
        auto_compact_threshold = 50,
        -- Timeout settings
        request_timeout = 300000, -- 5 minutes
        stream_timeout = 120000,  -- 2 minutes
        }

        -- Required for `opts.events.reload`.
        vim.o.autoread = true

        -- Main menu: <leader>a (press <leader>a and wait to see which-key menu)
        vim.keymap.set({ "n", "x" }, "<leader>aa", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask (@this)" })
        vim.keymap.set({ "n" }, "<leader>an", function() require("opencode").command("session.new") end, { desc = "New session" })
        vim.keymap.set({ "n" }, "<leader>au", function() require("opencode").command("session.undo") end, { desc = "Undo last action" })
        vim.keymap.set({ "n" }, "<leader>ar", function() require("opencode").command("session.redo") end, { desc = "Redo" })
        vim.keymap.set({ "n" }, "<leader>ac", function() require("opencode").command("session.compact") end, { desc = "Compact session" })
        vim.keymap.set({ "n" }, "<leader>as", function() require("opencode").command("session.select") end, { desc = "Select session" })
        vim.keymap.set({ "n" }, "<leader>aS", function() require("opencode").command("session.share") end, { desc = "Share session" })
        vim.keymap.set({ "n", "t" }, "<leader>at", function() require("opencode").toggle() end, { desc = "Toggle opencode" })
        vim.keymap.set({ "n", "x" }, "<leader>ax", function() require("opencode").select() end, { desc = "Execute action" })

        -- Prompts submenu: <leader>ap
        vim.keymap.set({ "n", "x" }, "<leader>ape", function() require("opencode").prompt("Explain @this and its context") end, { desc = "Explain" })
        vim.keymap.set({ "n", "x" }, "<leader>apf", function() require("opencode").prompt("Fix @diagnostics") end, { desc = "Fix diagnostics" })
        vim.keymap.set({ "n", "x" }, "<leader>apr", function() require("opencode").prompt("Review @this for correctness and readability") end, { desc = "Review" })
        vim.keymap.set({ "n", "x" }, "<leader>apd", function() require("opencode").prompt("Add comments documenting @this") end, { desc = "Document" })
        vim.keymap.set({ "n", "x" }, "<leader>apo", function() require("opencode").prompt("Optimize @this for performance and readability") end, { desc = "Optimize" })
        vim.keymap.set({ "n", "x" }, "<leader>apt", function() require("opencode").prompt("Add tests for @this") end, { desc = "Add tests" })

        -- Context/buffer submenu: <leader>ab
        vim.keymap.set({ "n" }, "<leader>abb", function() require("opencode").ask("@buffer: ", { submit = true }) end, { desc = "Send current buffer" })
        vim.keymap.set({ "n" }, "<leader>aba", function() require("opencode").ask("@buffers: ", { submit = true }) end, { desc = "Send all buffers" })
        vim.keymap.set({ "n" }, "<leader>abv", function() require("opencode").ask("@visible: ", { submit = true }) end, { desc = "Send visible text" })
        vim.keymap.set({ "n" }, "<leader>abd", function() require("opencode").ask("@diagnostics: ", { submit = true }) end, { desc = "Send diagnostics" })

        -- Navigation
        vim.keymap.set("n", "<S-C-u>", function() require("opencode").command("session.half.page.up") end, { desc = "opencode half page up" })
        vim.keymap.set("n", "<S-C-d>", function() require("opencode").command("session.half.page.down") end, { desc = "opencode half page down" })

        -- Operator (go + motion)
        vim.keymap.set({ "n", "x" }, "go", function() return require("opencode").operator("@this ") end, { expr = true, desc = "Add range to opencode" })
        vim.keymap.set("n", "goo", function() return require("opencode").operator("@this ") .. "_" end, { expr = true, desc = "Add line to opencode" })

        -- Restore + and - for increment/decrement (since we removed <C-a> and <C-x>)
        vim.keymap.set("n", "+", "<C-a>", { desc = "Increment", noremap = true })
        vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement", noremap = true })
    end,
  }
}
